<?php

namespace App\Support;

use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Http\Resources\Json\ResourceCollection;

/**
 * The single place where the API response envelope is produced.
 *
 *   { "success": true,  "message": "...", "data": ..., "pagination": {...} }
 *   { "success": false, "message": "...", "errors": { "field": ["..."] } }
 */
final class ApiResponse
{
    public static function ok(mixed $data = null, string $message = Msg::SUCCESS, int $status = 200): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => self::resolve($data),
        ], $status);
    }

    public static function created(mixed $data = null, string $message = Msg::CREATED): JsonResponse
    {
        return self::ok($data, $message, 201);
    }

    /** An action that has no resource to return. */
    public static function action(string $message = Msg::SUCCESS): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => null,
        ]);
    }

    /**
     * Paginated collection. `$transform` maps one model to its array form,
     * or a JsonResource class name may be passed instead.
     */
    public static function paginated(
        LengthAwarePaginator $paginator,
        callable|string|null $transform = null,
        string $message = Msg::FETCHED
    ): JsonResponse {
        $items = $paginator->getCollection();

        if (is_string($transform)) {
            $data = $transform::collection($items)->resolve();
        } elseif (is_callable($transform)) {
            $data = $items->map($transform)->values()->all();
        } else {
            $data = $items->values()->all();
        }

        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $data,
            'pagination' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => (int) $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    /**
     * @param  array<string, list<string>>  $errors
     */
    public static function fail(string $message, int $status = 400, array $errors = []): JsonResponse
    {
        $payload = [
            'success' => false,
            'message' => $message,
        ];

        if ($errors !== []) {
            $payload['errors'] = $errors;
        }

        return response()->json($payload, $status);
    }

    private static function resolve(mixed $data): mixed
    {
        if ($data instanceof JsonResource || $data instanceof ResourceCollection) {
            return $data->resolve();
        }

        return $data;
    }
}
