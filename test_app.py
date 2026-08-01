import pytest
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index_success(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.get_json()["message"] == "Welcome to the Flask CI/CD demo app"


def test_health_check_success(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"


def test_get_item_success(client):
    response = client.get("/items/1")
    assert response.status_code == 200
    body = response.get_json()
    assert body["id"] == 1
    assert body["name"] == "apple"


def test_get_item_not_found_failure_case(client):
    response = client.get("/items/999")
    assert response.status_code == 404
    assert response.get_json()["error"] == "item not found"


def test_unknown_route_returns_404(client):
    response = client.get("/does-not-exist")
    assert response.status_code == 404
