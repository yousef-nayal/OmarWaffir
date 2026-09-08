<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('location_id')->nullable()->constrained('locations')->restrictOnDelete();
            $table->string('name');
            $table->string('phone_number', 20)->unique();
            $table->string('email')->nullable()->unique();
            $table->string('password');
            // 0 = user, 1 = admin, 2 = super_admin
            $table->smallInteger('role')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamp('phone_verified_at')->nullable();
            $table->rememberToken();
            $table->timestamps();
            $table->softDeletes();

            $table->index('phone_number');
            $table->index('role');
            $table->index('location_id');
        });

        DB::statement('ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN (0, 1, 2))');
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
