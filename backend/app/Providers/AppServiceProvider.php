<?php

namespace App\Providers;

use App\Sms\LogSmsSender;
use App\Sms\NullSmsSender;
use App\Sms\SmsSenderInterface;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Swap in a real gateway here when one is available; the rest of the
        // application only ever talks to the interface.
        $this->app->bind(SmsSenderInterface::class, function () {
            return match (config('waffir.otp.sms_driver')) {
                'null' => new NullSmsSender(),
                default => new LogSmsSender(),
            };
        });
    }

    public function boot(): void
    {
        Model::preventLazyLoading(false);
        Model::unguard(false);

        if ($this->app->environment('production')) {
            URL::forceScheme('https');
        }
    }
}
