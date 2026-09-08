<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('auth_otps', function (Blueprint $table) {
            $table->bigIncrements('id');
            // Nullable so a recovery OTP can exist before the user row is known.
            $table->foreignId('user_id')->nullable()->constrained('users')->cascadeOnDelete();
            $table->string('phone_number', 20);
            // registration | password_reset | password_change
            $table->string('purpose', 32);
            // The OTP itself is NEVER stored in plaintext.
            $table->string('otp_hash');
            $table->unsignedInteger('attempts')->default(0);
            $table->boolean('is_used')->default(false);
            $table->timestamp('expires_at');
            $table->timestamp('verified_at')->nullable();
            $table->timestamp('created_at')->nullable();

            $table->index(['phone_number', 'purpose']);
            $table->index('expires_at');
        });

        DB::statement("ALTER TABLE auth_otps ADD CONSTRAINT auth_otps_purpose_check CHECK (purpose IN ('registration', 'password_reset', 'password_change'))");
    }

    public function down(): void
    {
        Schema::dropIfExists('auth_otps');
    }
};
