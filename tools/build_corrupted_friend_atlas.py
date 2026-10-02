"""Build the fixed-cell Corrupted Friend sprite atlas.

The generated source strips intentionally live under art_concepts so the game
only imports the normalized atlas emitted under img/.  Pillow is the only
external dependency.
"""

from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "art_concepts" / "corrupted_friend_v3"
OUTPUT_PATH = ROOT / "img" / "characters" / "corrupted_friend" / "corrupted_friend_v3_atlas.png"

DIRECTIONS = (
    "front",
    "front_right",
    "right",
    "back_right",
    "back",
    "back_left",
    "left",
    "front_left",
)
CHASE_SOURCES = {
    direction: SOURCE_DIR / f"chase_{direction}.png" for direction in DIRECTIONS
}

CELL_WIDTH = 320
CELL_HEIGHT = 384
ATLAS_COLUMNS = 8
ATLAS_ROWS = 9
GROUND_Y = 368
MAX_SPRITE_WIDTH = 288
MAX_SPRITE_HEIGHT = 336
ALPHA_BOUNDS_THRESHOLD = 32

# The old states sheet's generated profile views landed in swapped columns.
LEGACY_STATE_DIRECTION_MAP = (0, 1, 6, 3, 4, 5, 2, 7)


def _runs(values: tuple[int, ...]) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    start: int | None = None
    for index, value in enumerate(values):
        if value and start is None:
            start = index
        elif not value and start is not None:
            ranges.append((start, index))
            start = None
    if start is not None:
        ranges.append((start, len(values)))
    return ranges


def _opaque_mask(image: Image.Image) -> Image.Image:
    return image.getchannel("A").point(
        lambda alpha: 255 if alpha >= ALPHA_BOUNDS_THRESHOLD else 0
    )


def _remove_magenta_key(image: Image.Image) -> Image.Image:
    """Convert the prototype's magenta key to alpha and despill its edges."""
    red, green, blue, alpha = image.convert("RGBA").split()
    key = ImageChops.subtract(ImageChops.darker(red, blue), green)
    keep = key.point(
        lambda value: 255
        if value <= 15
        else 0
        if value >= 56
        else round(255.0 * (56 - value) / 41.0)
    )
    clean_alpha = ImageChops.multiply(alpha, keep)
    spill = key.point(lambda value: value if value > 5 else 0)
    clean_red = ImageChops.subtract(red, spill)
    clean_blue = ImageChops.subtract(blue, spill)
    return Image.merge("RGBA", (clean_red, green, clean_blue, clean_alpha))


def _crop_subject(image: Image.Image) -> Image.Image:
    mask = _opaque_mask(image)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError("Sprite region contains no visible pixels")
    left, top, right, bottom = bounds
    left = max(0, left - 2)
    top = max(0, top - 2)
    right = min(image.width, right + 2)
    bottom = min(image.height, bottom + 2)
    sprite = image.crop((left, top, right, bottom)).convert("RGBA")
    red, green, blue, alpha = sprite.split()
    alpha = alpha.point(lambda value: 0 if value < 8 else value)
    return Image.merge("RGBA", (red, green, blue, alpha))


def _split_subjects(
    image: Image.Image, expected_columns: int, expected_rows: int
) -> list[Image.Image]:
    """Find blank separators without assuming generated art is a perfect grid."""
    image = image.convert("RGBA")
    mask = _opaque_mask(image)
    _, y_projection = mask.getprojection()
    row_ranges = _runs(y_projection)
    if expected_rows == 1:
        row_ranges = [(0, image.height)]
    elif len(row_ranges) != expected_rows:
        row_ranges = [
            (
                round(row * image.height / expected_rows),
                round((row + 1) * image.height / expected_rows),
            )
            for row in range(expected_rows)
        ]

    subjects: list[Image.Image] = []
    for row_start, row_end in row_ranges:
        row_image = image.crop((0, row_start, image.width, row_end))
        row_mask = _opaque_mask(row_image)
        x_projection, _ = row_mask.getprojection()
        column_ranges = _runs(x_projection)
        if len(column_ranges) != expected_columns:
            column_ranges = [
                (
                    round(column * image.width / expected_columns),
                    round((column + 1) * image.width / expected_columns),
                )
                for column in range(expected_columns)
            ]
        for column_start, column_end in column_ranges:
            subject = row_image.crop((column_start, 0, column_end, row_image.height))
            subjects.append(_crop_subject(subject))

    expected_count = expected_columns * expected_rows
    if len(subjects) != expected_count:
        raise ValueError(f"Expected {expected_count} sprites, found {len(subjects)}")
    return subjects


def _normalized_cell(sprite: Image.Image) -> Image.Image:
    scale = min(
        MAX_SPRITE_WIDTH / sprite.width,
        MAX_SPRITE_HEIGHT / sprite.height,
    )
    size = (
        max(1, round(sprite.width * scale)),
        max(1, round(sprite.height * scale)),
    )
    # Resize premultiplied color so hidden background RGB cannot create a halo.
    sprite = (
        sprite.convert("RGBa")
        .resize(size, Image.Resampling.LANCZOS)
        .convert("RGBA")
    )
    cell = Image.new("RGBA", (CELL_WIDTH, CELL_HEIGHT), (0, 0, 0, 0))
    position = ((CELL_WIDTH - sprite.width) // 2, GROUND_Y - sprite.height)
    cell.alpha_composite(sprite, position)
    return cell


def _place(
    atlas: Image.Image, sprite: Image.Image, column: int, row: int
) -> None:
    atlas.alpha_composite(
        _normalized_cell(sprite),
        (column * CELL_WIDTH, row * CELL_HEIGHT),
    )


def build() -> None:
    idle = _split_subjects(
        Image.open(SOURCE_DIR / "idle_turnaround.png"), 4, 2
    )
    chase = {
        direction: _split_subjects(Image.open(path), 4, 1)
        for direction, path in CHASE_SOURCES.items()
    }

    legacy_states = _split_subjects(
        _remove_magenta_key(
            Image.open(ROOT / "img" / "characters" / "corrupted_friend" / "directional_states.png")
        ),
        8,
        4,
    )
    legacy_death = _split_subjects(
        _remove_magenta_key(
            Image.open(ROOT / "img" / "characters" / "corrupted_friend" / "directional_death.png")
        ),
        4,
        2,
    )

    atlas = Image.new(
        "RGBA",
        (CELL_WIDTH * ATLAS_COLUMNS, CELL_HEIGHT * ATLAS_ROWS),
        (0, 0, 0, 0),
    )

    for direction_index, direction in enumerate(DIRECTIONS):
        _place(atlas, idle[direction_index], direction_index, 0)
        for frame_index, frame in enumerate(chase[direction]):
            _place(atlas, frame, direction_index, frame_index + 1)

        legacy_column = LEGACY_STATE_DIRECTION_MAP[direction_index]
        _place(atlas, legacy_states[8 + legacy_column], direction_index, 5)
        _place(atlas, legacy_states[16 + legacy_column], direction_index, 6)
        _place(atlas, legacy_states[24 + legacy_column], direction_index, 7)
        _place(atlas, legacy_death[direction_index], direction_index, 8)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT_PATH, optimize=True)
    print(
        f"Wrote {OUTPUT_PATH.relative_to(ROOT)} "
        f"({atlas.width}x{atlas.height}, {ATLAS_COLUMNS}x{ATLAS_ROWS} cells)"
    )


if __name__ == "__main__":
    build()
