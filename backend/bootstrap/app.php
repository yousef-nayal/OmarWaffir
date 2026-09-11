<?php

use App\Http\Middleware\AddContentLength;
use App\Http\Middleware\EnsureActiveUser;
use App\Http\Middleware\EnsureRole;
use App\Http\Middleware\ForceJsonResponse;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        apiPrefix: 'api/v1',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->api(prepend: [
            // Outermost on purpose: it has to see the finished response,
            // including the ones rendered from exceptions.
            AddContentLength::class,
            ForceJsonResponse::class,
            \Illuminate\Http\Middleware\HandleCors::class,
        ]);

        $middleware->alias([
            'role' => EnsureRole::class,
            'active' => EnsureActiveUser::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Raw Laravel exceptions must never reach Flutter: every error leaves
        // the API in the documented envelope, with an Arabic message.
        $exceptions->render(function (Throwable $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            if ($e instanceof ValidationException) {
                return ApiResponse::fail(
                    $e->validator->errors()->first() ?: Msg::VALIDATION,
                    422,
                    $e->errors(),
                );
            }

            if ($e instanceof AuthenticationException) {
                return ApiResponse::fail(Msg::UNAUTHENTICATED, 401);
            }

            if ($e instanceof AuthorizationException) {
                return ApiResponse::fail(Msg::FORBIDDEN, 403);
            }

            if ($e instanceof ModelNotFoundException || $e instanceof NotFoundHttpException) {
                return ApiResponse::fail(Msg::NOT_FOUND, 404);
            }

            if ($e instanceof TooManyRequestsHttpException) {
                return ApiResponse::fail(Msg::RATE_LIMITED, 429);
            }

            if ($e instanceof QueryException) {
                // 23503 = foreign key violation -> the row is still referenced.
                if (in_array($e->getCode(), ['23503', '23P01'], true)) {
                    return ApiResponse::fail(Msg::IN_USE, 409);
                }

                report($e);

                return ApiResponse::fail(
                    config('app.debug') ? $e->getMessage() : Msg::SERVER_ERROR,
                    500,
                );
            }

            if ($e instanceof HttpExceptionInterface) {
                $status = $e->getStatusCode();

                return ApiResponse::fail(
                    $e->getMessage() !== '' ? $e->getMessage() : match ($status) {
                        401 => Msg::UNAUTHENTICATED,
                        403 => Msg::FORBIDDEN,
                        404 => Msg::NOT_FOUND,
                        405 => Msg::METHOD_NOT_ALLOWED,
                        429 => Msg::RATE_LIMITED,
                        default => Msg::SERVER_ERROR,
                    },
                    $status,
                );
            }

            report($e);

            return ApiResponse::fail(
                config('app.debug') ? $e->getMessage() : Msg::SERVER_ERROR,
                500,
            );
        });
    })->create();
