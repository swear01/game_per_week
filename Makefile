.PHONY: test test-deck-merger test-jupyter

test: test-deck-merger test-jupyter

test-deck-merger:
	cd deck_merger && uv run --extra dev pytest tests/ -v

test-jupyter:
	PYTHONPATH=tests/jupyter python3 -m unittest discover -s tests/jupyter -p 'test_*.py'
