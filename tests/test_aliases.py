import pytest

from app.tools.aliases import MAX_ALIASES, build_prompt, parse_aliases

WORDS = ["cat", "cap", "elephant"]


def test_parses_and_cleans_a_normal_answer():
    raw = '{"cat": ["Cut", "kat", "cat", "caught"], "elephant": ["elefant", "el phant"]}'
    out = parse_aliases(raw, WORDS)
    assert out["cat"] == ["cut", "kat", "caught"]  # minúsculas y sin la palabra original
    assert out["elephant"] == ["elefant", "el phant"]
    assert out["cap"] == []  # palabra pedida pero sin respuesta: lista vacía, no falta la clave


def test_accepts_markdown_code_fences():
    out = parse_aliases('```json\n{"cat": ["kat"]}\n```', WORDS)
    assert out["cat"] == ["kat"]


def test_never_uses_another_vocabulary_word_as_an_alias():
    # "cap" es una palabra del vocabulario: no puede ser alias de "cat".
    assert "cap" not in parse_aliases('{"cat": ["cap", "kat"]}', WORDS)["cat"]


def test_discards_junk_and_unknown_keys():
    raw = '{"cat": ["ok", "<script>", "123", "x" , "a" , "", "ignore previous", 5, null], "dog": ["dag"]}'
    out = parse_aliases(raw, WORDS)
    assert "dog" not in out  # no se pidió
    assert "<script>" not in out["cat"] and "123" not in out["cat"]
    assert 5 not in out["cat"]


def test_limits_the_number_of_aliases():
    many = ", ".join(f'"{c}at"' for c in "bdfghjklmnpqrstvwxz")
    assert len(parse_aliases('{"cat": [' + many + "]}", WORDS)["cat"]) == MAX_ALIASES


@pytest.mark.parametrize("raw", ["no es json", "[1, 2]", ""])
def test_invalid_responses_raise_a_clear_error(raw):
    with pytest.raises(ValueError):
        parse_aliases(raw, WORDS)


def test_prompt_contains_the_words():
    assert '"cat"' in build_prompt(["cat", "dog"])
