<?php

namespace App\Http\Middleware;

use App\Support\ApiResponse;
use App\Support\Msg;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Server-side authorisation boundary. The Flutter route a screen lives on is
 * never trusted: every admin endpoint passes through this middleware.
 *
 * Usage: ->middleware('role:1') or ->middleware('role:2')
 */
class EnsureRole
{
    public function handle(Request $request, Closure $next, string $minimumRole): Response
    {
        $user = $request->user();

        if ($user === null) {
            return ApiResponse::fail(Msg::UNAUTHENTICATED, 401);
        }

        if (! $user->is_active) {
            return ApiResponse::fail(Msg::ACCOUNT_BLOCKED, 403);
        }

        if ($user->role < (int) $minimumRole) {
            return ApiResponse::fail(Msg::FORBIDDEN, 403);
        }

        return $next($request);
    }
}
