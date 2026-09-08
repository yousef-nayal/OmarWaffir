<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ratings', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('price_id')->constrained('prices')->cascadeOnDelete();
            // true = thumbs up, false = thumbs down
            $table->boolean('value');
            $table->timestamps();

            // The database is the final concurrency guarantee for one vote per user.
            $table->unique(['user_id', 'price_id']);
            $table->index('price_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ratings');
    }
};
