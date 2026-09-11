<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PriceResource;
use App\Http\Resources\ProductResource;
use App\Models\Price;
use App\Models\Product;
use App\Services\DeletionImpactService;
use App\Services\PriceAggregationService;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ProductController extends Controller
{
    public function __construct(
        private readonly PriceAggregationService $aggregation,
        private readonly DeletionImpactService $impact,
    ) {
    }

    /**
     * GET /products?search=&category=&location_id=&sort=&page=&per_page=
     *
     * The money fields in the response are computed per requested location -
     * they are not columns on `products`.
     *
     * sort=gap ranks by how far the market price runs above the official one
     * for the requested location, biggest gap first. That ordering cannot be
     * expressed in SQL here: both figures come from PriceAggregationService
     * (median with outlier rejection), not from a column, so the rows are
     * aggregated first and ordered afterwards. See gapSorted().
     */
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'sort' => ['nullable', 'string', Rule::in(['name', 'gap'])],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Product::query();

        // The admin and user product screens both advertise this box as
        // "name or category", so the term has to reach `category` as well -
        // matching only `name` made every category term look like no results.
        if (! empty($filters['search'])) {
            $term = '%'.$filters['search'].'%';
            $query->where(function ($q) use ($term) {
                $q->where('name', 'ILIKE', $term)
                    ->orWhere('category', 'ILIKE', $term);
            });
        }

        if (! empty($filters['category']) && $filters['category'] !== 'الكل') {
            $query->where('category', $filters['category']);
        }

        $locationId = isset($filters['location_id']) ? (int) $filters['location_id'] : null;

        if (($filters['sort'] ?? 'name') === 'gap') {
            return ApiResponse::paginated(
                $this->gapSorted($query, $request, $filters, $locationId),
                ProductResource::class,
            );
        }

        $paginator = $query->orderBy('name')
            ->paginate((int) ($filters['per_page'] ?? 20))
            ->withQueryString();

        $this->attachAggregates($paginator->getCollection()->all(), $locationId);

        return ApiResponse::paginated($paginator, ProductResource::class);
    }

    /**
     * Products ordered by (real price - official price) for one location.
     *
     * Aggregates have to be computed before the ordering exists, so the whole
     * filtered set is aggregated - PriceAggregationService::forProducts runs a
     * fixed number of queries for any number of products - and then paginated
     * by hand.
     *
     * A product without both figures has no gap to speak of (no official price
     * recorded, or no submission from this location yet). Those keep their
     * place in the catalogue but sink below every comparable product instead of
     * polluting the top of the ranking.
     *
     * @param  \Illuminate\Database\Eloquent\Builder<Product>  $query
     * @param  array<string, mixed>  $filters
     * @return LengthAwarePaginator<int, Product>
     */
    private function gapSorted(
        $query,
        Request $request,
        array $filters,
        ?int $locationId,
    ): LengthAwarePaginator {
        $products = $query->orderBy('name')->get();

        $this->attachAggregates($products->all(), $locationId);

        $ranked = $products
            ->sortByDesc(static function (Product $product): float {
                $agg = $product->aggregates ?? [];
                $official = (float) ($agg['official_price'] ?? 0);
                $real = (float) ($agg['real_price'] ?? 0);

                return $official > 0 && $real > 0
                    ? $real - $official
                    : -INF;
            })
            ->values();

        $perPage = (int) ($filters['per_page'] ?? 20);
        $page = (int) ($filters['page'] ?? 1);

        return new LengthAwarePaginator(
            $ranked->forPage($page, $perPage)->values(),
            $ranked->count(),
            $perPage,
            $page,
            ['path' => $request->url(), 'query' => $request->query()],
        );
    }

    /** GET /products/{product}?location_id= */
    public function show(Request $request, Product $product): JsonResponse
    {
        $filters = $request->validate([
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
        ]);

        $this->attachAggregates(
            [$product],
            isset($filters['location_id']) ? (int) $filters['location_id'] : null,
        );

        return ApiResponse::ok(new ProductResource($product), Msg::FETCHED);
    }

    /**
     * GET /products/{product}/prices?location_id=
     *
     * Every market price recorded for a product, newest first.
     */
    public function prices(Request $request, Product $product): JsonResponse
    {
        $filters = $request->validate([
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:200'],
        ]);

        $query = Price::query()
            ->where('product_id', $product->id)
            ->with(['product', 'unit', 'brand', 'user', 'store.location.sector'])
            ->withCount([
                'ratings as thumbs_up' => fn ($q) => $q->where('value', true),
                'ratings as thumbs_down' => fn ($q) => $q->where('value', false),
            ]);

        if (! empty($filters['location_id'])) {
            $query->whereHas('store', fn ($q) => $q->where('location_id', (int) $filters['location_id']));
        }

        if ($request->user() !== null) {
            $query->with(['myRating' => fn ($q) => $q->where('user_id', $request->user()->id)]);
        }

        $prices = $query->orderByDesc('created_at')
            ->limit((int) ($filters['per_page'] ?? 100))
            ->get();

        return ApiResponse::ok(PriceResource::collection($prices), Msg::FETCHED);
    }

    /** POST /products - admin. */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'max:255'],
        ]);

        $product = Product::create($data);
        $this->attachAggregates([$product], null);

        return ApiResponse::created(new ProductResource($product));
    }

    /** PUT /products/{product} - admin. */
    public function update(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'max:255'],
        ]);

        $product->update($data);
        $this->attachAggregates([$product], null);

        return ApiResponse::ok(new ProductResource($product), Msg::UPDATED);
    }

    /**
     * DELETE /products/{product} - admin.
     *
     * The product row is soft deleted; every price recorded for it - market
     * submissions and official prices alike - is removed for good. The app
     * warns with those counts first (GET /admin/deletion-impact/product/{id}).
     */
    public function destroy(Product $product): JsonResponse
    {
        DB::transaction(function () use ($product): void {
            $this->impact->purge('product', $product->id);
            $product->delete();
        });

        return ApiResponse::action(Msg::DELETED);
    }

    /** GET /products/categories - distinct category list for the filter chips. */
    public function categories(): JsonResponse
    {
        $categories = Product::query()
            ->select('category')
            ->distinct()
            ->orderBy('category')
            ->pluck('category')
            ->all();

        return ApiResponse::ok($categories, Msg::FETCHED);
    }

    /**
     * @param  list<Product>  $products
     */
    private function attachAggregates(array $products, ?int $locationId): void
    {
        if ($products === []) {
            return;
        }

        $aggregates = $this->aggregation->forProducts(
            array_map(static fn (Product $p): int => $p->id, $products),
            $locationId,
        );

        foreach ($products as $product) {
            $product->aggregates = $aggregates[$product->id] ?? [];
        }
    }
}
