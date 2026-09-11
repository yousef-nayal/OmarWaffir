<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Services\DeletionImpactService;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * GET /admin/deletion-impact/{type}/{id}
 *
 * What the admin is about to take down with this row. The dialog in the app
 * asks first and words its warning from these numbers, so it is never a guess:
 * the same service performs the deletion.
 */
class DeletionImpactController extends Controller
{
    public function __construct(private readonly DeletionImpactService $impact)
    {
    }

    public function show(string $type, int $id): JsonResponse
    {
        if (! in_array($type, DeletionImpactService::TYPES, true)) {
            throw ValidationException::withMessages([
                'type' => [Msg::VALIDATION],
            ]);
        }

        $model = $this->impact->modelFor($type);

        // withTrashed() where the model supports it: a soft-deleted row still
        // holds its foreign keys, and its prices still count.
        $query = method_exists($model, 'withTrashed') ? $model::withTrashed() : $model::query();

        if (! $query->whereKey($id)->exists()) {
            return ApiResponse::fail(Msg::NOT_FOUND, 404);
        }

        return ApiResponse::ok($this->impact->impact($type, $id), Msg::FETCHED);
    }
}
