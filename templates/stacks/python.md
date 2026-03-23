# Python Stack Template

## Recommended MCP Servers
- **context7** — Documentation lookup for Python packages and frameworks

## Recommended Permissions
```json
"Bash(python:*)", "Bash(python3:*)", "Bash(pip:*)", "Bash(uv:*)",
"Bash(poetry:*)", "Bash(pytest:*)", "Bash(ruff:*)", "Bash(mypy:*)"
```

## Agent Modifications

### Researcher
- Should check `pyproject.toml`, `setup.py`, `requirements.txt` for dependencies
- Should detect virtual environment setup (venv, poetry, uv)
- Should identify Django/FastAPI/Flask from imports and configs

### Implementer
- Should know about: Ruff, Black, mypy, pytest
- Should use the detected package manager (uv, poetry, pip)
- Common commands vary by manager:
  - uv: `uv run pytest`, `uv run ruff check`, `uv run mypy`
  - poetry: `poetry run pytest`, `poetry run ruff check`
  - pip: `python -m pytest`, `ruff check .`, `mypy .`

### Reviewer
- Should check for type hints usage
- Should validate Ruff/Black formatting consistency
- Should check for proper `__init__.py` files

## Recommended Skills

### /typecheck
Run type checker: `mypy .` or `pyright`

### /lint-fix
Run linter with auto-fix: `ruff check --fix .` and `ruff format .`

### /test
Run tests with coverage: `pytest --cov` or `uv run pytest --cov`

## Recommended Rules

### Python files
```yaml
paths:
  - "**/*.py"
```
- Use type hints for function signatures
- Follow PEP 8 conventions (enforced by Ruff)
- Use dataclasses or Pydantic models for data structures
- Prefer pathlib over os.path

## Framework-Specific Notes

### Django
- Settings module detection (`settings.py`, `DJANGO_SETTINGS_MODULE`)
- URL routing patterns
- Model/View/Template structure
- Management commands: `python manage.py migrate`, `python manage.py test`

### FastAPI
- Router organization
- Pydantic models for request/response
- Dependency injection patterns
- `uvicorn` for development server

### Flask
- Blueprint organization
- Application factory pattern
- Extension usage (SQLAlchemy, Marshmallow, etc.)
