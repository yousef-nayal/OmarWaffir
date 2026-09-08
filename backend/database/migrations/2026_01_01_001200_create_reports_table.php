<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * The three allowed report types, kept as \u escapes so the file stays
     * ASCII-safe on every toolchain. They are exactly:
     *   overpriced   -> "سعر مبالغ فيه"
     *   wrong price  -> "سعر غير صحيح"
     *   wrong info   -> "معلومات غير صحيحة"
     */
    private const TYPE_OVERPRICED = "\u{633}\u{639}\u{631} \u{645}\u{628}\u{627}\u{644}\u{63A} \u{641}\u{64A}\u{647}";
    private const TYPE_WRONG_PRICE = "\u{633}\u{639}\u{631} \u{63A}\u{64A}\u{631} \u{635}\u{62D}\u{64A}\u{62D}";
    private const TYPE_WRONG_INFO = "\u{645}\u{639}\u{644}\u{648}\u{645}\u{627}\u{62A} \u{63A}\u{64A}\u{631} \u{635}\u{62D}\u{64A}\u{62D}\u{629}";

    public function up(): void
    {
        Schema::create('reports', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('price_id')->constrained('prices')->cascadeOnDelete();
            $table->string('type');
            $table->text('description')->nullable();
            $table->timestamps();

            $table->index('price_id');
            $table->index('type');
        });

        $types = implode(', ', array_map(
            fn (string $t): string => "'".str_replace("'", "''", $t)."'",
            [self::TYPE_OVERPRICED, self::TYPE_WRONG_PRICE, self::TYPE_WRONG_INFO],
        ));

        DB::statement("ALTER TABLE reports ADD CONSTRAINT reports_type_check CHECK (type IN ($types))");

        // description is only meaningful for the "wrong information" type.
        DB::statement(
            "ALTER TABLE reports ADD CONSTRAINT reports_description_check CHECK (type = '"
            .self::TYPE_WRONG_INFO."' OR description IS NULL)"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('reports');
    }
};
