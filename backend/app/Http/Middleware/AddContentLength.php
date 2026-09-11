<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Declares the body length on every API response.
 *
 * PHP's built-in server - which is what `php artisan serve` runs - sends no
 * Content-Length and no Transfer-Encoding: it marks the end of the body by
 * closing the connection. curl on localhost is happy with that, so it is
 * invisible in local testing. A tunnel in front of it (VS Code dev tunnels,
 * ngrok, Cloudflare) re-frames the response as chunked and keeps the client
 * connection alive, but has no length to work from, so the terminating chunk
 * never arrives: the phone downloads the whole body and then waits until Dio's
 * 30s timeout fires - "the request took too long".
 *
 * Setting the header explicitly lets any proxy end the response properly.
 */
class AddContentLength
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        // Streamed and file responses have no in-memory body to measure, and
        // their length is either unknown or already set by the sender.
        if ($response instanceof StreamedResponse || $response instanceof BinaryFileResponse) {
            return $response;
        }

        if (! $response->headers->has('Content-Length') && ! $response->headers->has('Transfer-Encoding')) {
            $response->headers->set('Content-Length', (string) strlen((string) $response->getContent()));
        }

        return $response;
    }
}
