<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PriceResource;
use App\Http\Resources\ProductResource;
use App\Models\Price;
use App\Models\Product;
use App\Services\PriceAggregationService;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ProductController extends Controller
{
    public function __construct(private readonly PriceAggregationService $aggregation)
    {
    }

    /**
     * GET /products?search=&category=&location_id=&page=&per_page=
     *
     * The money fields in the response are computed per requested location -
     * they are not columns on `products`.
     */
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Product::query();

        if (! empty($filters['search'])) {
            $query->where('name', 'ILIKE', '%'.$filters['search'].'%');
        }

        if (! empty($filters['category']) && $filters['category'] !== 'الكل') {
            $query->where('category', $filters['category']);
        }

        $paginator = $query->orderBy('name')
            ->paginate((int) ($filters['per_page'] ?? 20))
            ->withQueryString();

        $this->attachAggregates(
            $paginator->getCollection()->all(),
            isset($filters['location_id']) ? (int) $filters['location_id'] : null,
        );

        return ApiResponse::paginated($paginator, ProductResource::class);
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
     * Soft delete: historic prices that reference the product are preserved.
     */
    public function destroy(Product $product): JsonResponse
    {
        $product->delete();

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
