<?php

namespace App\Http\Middleware;

use App\Support\ApiResponse;
use App\Support\Msg;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * A blocked user keeps their access token until it expires; this middleware
 * makes sure the token stops working the moment the account is deactivated.
 */
class EnsureActiveUser
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user !== null && ! $user->is_active) {
            return ApiResponse::fail(Msg::ACCOUNT_BLOCKED, 403);
        }

        return $next($request);
    }
}
