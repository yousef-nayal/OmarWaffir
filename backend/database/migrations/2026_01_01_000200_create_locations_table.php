<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('locations', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('sector_id')->constrained('sectors')->restrictOnDelete();
            // `district` is the canonical wire/DB term. Flutter shows it as "area".
            $table->string('district');
            $table->timestamps();

            $table->unique(['sector_id', 'district']);
            $table->index('sector_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('locations');
    }
};
