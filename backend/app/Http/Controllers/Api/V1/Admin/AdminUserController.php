<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

/**
 * Administrative user management.
 *
 * Role rules enforced here (never in Flutter):
 *  - only a super admin (role 2) may create, edit, delete or re-role an admin
 *  - nobody may act on their own account through these endpoints
 *  - the last remaining super admin cannot be removed or demoted
 */
class AdminUserController extends Controller
{
    /** GET /admin/users */
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', Rule::in(['active', 'blocked'])],
            'sector_id' => ['nullable', 'integer', 'exists:sectors,id'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'role' => ['nullable', 'integer', Rule::in([0, 1, 2])],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = User::query()
            ->with('location.sector')
            ->withCount(['prices', 'ratings', 'reports']);

        if (! empty($filters['search'])) {
            $search = '%'.$filters['search'].'%';
            $query->where(function ($q) use ($search) {
                $q->where('name', 'ILIKE', $search)
                    ->orWhere('phone_number', 'ILIKE', $search)
                    ->orWhere('email', 'ILIKE', $search);
            });
        }

        if (! empty($filters['status'])) {
            $query->where('is_active', $filters['status'] === 'active');
        }

        if (isset($filters['role'])) {
            $query->where('role', (int) $filters['role']);
        }

        if (! empty($filters['location_id'])) {
            $query->where('location_id', (int) $filters['location_id']);
        }

        if (! empty($filters['sector_id'])) {
            $query->whereHas('location', fn ($q) => $q->where('sector_id', (int) $filters['sector_id']));
        }

        $paginator = $query->orderByDesc('created_at')
            ->paginate((int) ($filters['per_page'] ?? 20))
            ->withQueryString();

        return ApiResponse::paginated($paginator, UserResource::class);
    }

    /** POST /admin/users */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:255'],
            'phone_number' => [
                'required', 'string', 'regex:/^[0-9+]{9,15}$/',
                Rule::unique('users', 'phone_number')->whereNull('deleted_at'),
            ],
            'email' => ['nullable', 'email', 'max:255', Rule::unique('users', 'email')->whereNull('deleted_at')],
            'password' => ['required', 'string', 'min:6', 'max:255'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'role' => ['nullable', 'integer', Rule::in([0, 1, 2])],
        ]);

        $role = (int) ($data['role'] ?? User::ROLE_USER);
        $actor = $request->user();

        if ($role >= User::ROLE_ADMIN && ! $actor->isSuperAdmin()) {
            return ApiResponse::fail(Msg::CANNOT_MANAGE_ADMIN, 403);
        }

        $user = User::create([
            'name' => $data['name'],
            'phone_number' => $data['phone_number'],
            'email' => $data['email'] ?? null,
            'password' => $data['password'],
            'location_id' => isset($data['location_id']) ? (int) $data['location_id'] : null,
            'role' => $role,
            'is_active' => true,
            // Accounts created by an administrator are trusted immediately.
            'phone_verified_at' => Carbon::now(),
        ]);

        return ApiResponse::created(new UserResource($this->hydrate($user)));
    }

    /** PUT /admin/users/{user} */
    public function update(Request $request, User $user): JsonResponse
    {
        if ($guard = $this->guardTarget($request, $user)) {
            return $guard;
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:255'],
            'phone_number' => [
                'nullable', 'string', 'regex:/^[0-9+]{9,15}$/',
                Rule::unique('users', 'phone_number')->ignore($user->id)->whereNull('deleted_at'),
            ],
            'email' => [
                'nullable', 'email', 'max:255',
                Rule::unique('users', 'email')->ignore($user->id)->whereNull('deleted_at'),
            ],
            'password' => ['nullable', 'string', 'min:6', 'max:255'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
        ]);

        $user->name = $data['name'];

        if (! empty($data['phone_number'])) {
            $user->phone_number = $data['phone_number'];
        }

        if (array_key_exists('email', $data)) {
            $user->email = $data['email'];
        }

        if (! empty($data['password'])) {
            $user->password = $data['password'];
        }

        if (! empty($data['location_id'])) {
            $user->location_id = (int) $data['location_id'];
        }

        $user->save();

        return ApiResponse::ok(new UserResource($this->hydrate($user)), Msg::UPDATED);
    }

    /** PATCH /admin/users/{user}/block */
    public function block(Request $request, User $user): JsonResponse
    {
        if ($guard = $this->guardTarget($request, $user)) {
            return $guard;
        }

        $user->update(['is_active' => false]);

        // A blocked account must lose access immediately, not when its
        // access token happens to expire.
        $user->tokens()->delete();
        $user->refreshTokens()->whereNull('revoked_at')->update(['revoked_at' => Carbon::now()]);

        return ApiResponse::ok(new UserResource($this->hydrate($user)), Msg::USER_BLOCKED);
    }

    /** PATCH /admin/users/{user}/unblock */
    public function unblock(Request $request, User $user): JsonResponse
    {
        if ($guard = $this->guardTarget($request, $user)) {
            return $guard;
        }

        $user->update(['is_active' => true]);

        return ApiResponse::ok(new UserResource($this->hydrate($user)), Msg::USER_UNBLOCKED);
    }

    /** PATCH /admin/users/{user}/role */
    public function setRole(Request $request, User $user): JsonResponse
    {
        $data = $request->validate([
            'role' => ['required', 'integer', Rule::in([0, 1, 2])],
        ]);

        $actor = $request->user();
        $newRole = (int) $data['role'];

        if ($actor->id === $user->id) {
            return ApiResponse::fail(Msg::CANNOT_MODIFY_SELF, 403);
        }

        // Touching an administrator, or promoting anybody to one, is reserved
        // for the super admin.
        if (($user->isAdmin() || $newRole >= User::ROLE_ADMIN) && ! $actor->isSuperAdmin()) {
            return ApiResponse::fail(Msg::CANNOT_MANAGE_ADMIN, 403);
        }

        if ($user->isSuperAdmin() && $newRole < User::ROLE_SUPER_ADMIN && $this->superAdminCount() <= 1) {
            return ApiResponse::fail(Msg::CANNOT_DELETE_LAST_SUPER_ADMIN, 409);
        }

        $user->update(['role' => $newRole]);

        return ApiResponse::ok(new UserResource($this->hydrate($user)), Msg::ROLE_UPDATED);
    }

    /**
     * DELETE /admin/users/{user}
     *
     * Soft delete: prices, ratings and reports contributed by the account are
     * preserved for the historical record.
     */
    public function destroy(Request $request, User $user): JsonResponse
    {
        if ($guard = $this->guardTarget($request, $user)) {
            return $guard;
        }

        if ($user->isSuperAdmin() && $this->superAdminCount() <= 1) {
            return ApiResponse::fail(Msg::CANNOT_DELETE_LAST_SUPER_ADMIN, 409);
        }

        $user->tokens()->delete();
        $user->delete();

        return ApiResponse::action(Msg::DELETED);
    }

    /** Shared guard: self-modification and admin-on-admin protection. */
    private function guardTarget(Request $request, User $target): ?JsonResponse
    {
        $actor = $request->user();

        if ($actor->id === $target->id) {
            return ApiResponse::fail(Msg::CANNOT_MODIFY_SELF, 403);
        }

        if ($target->isAdmin() && ! $actor->isSuperAdmin()) {
            return ApiResponse::fail(Msg::CANNOT_MANAGE_ADMIN, 403);
        }

        return null;
    }

    private function superAdminCount(): int
    {
        return User::where('role', User::ROLE_SUPER_ADMIN)->count();
    }

    private function hydrate(User $user): User
    {
        return $user->fresh()->load('location.sector')->loadCount(['prices', 'ratings', 'reports']);
    }
}
