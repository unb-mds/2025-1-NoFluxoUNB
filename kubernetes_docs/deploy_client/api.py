from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import requests


@dataclass(frozen=True)
class ApiError(RuntimeError):
    status_code: int
    url: str
    body: str


class DeployApiClient:
    def __init__(self, api_url: str, api_key: str, timeout_s: float = 30.0) -> None:
        self._api_url = api_url.rstrip("/")
        self._timeout_s = timeout_s
        self._session = requests.Session()
        self._session.headers.update({"X-API-Key": api_key})

    def _url(self, path: str) -> str:
        if not path.startswith("/"):
            path = "/" + path
        return self._api_url + path

    def _request_json(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: Any | None = None,
    ) -> Any:
        url = self._url(path)
        res = self._session.request(
            method,
            url,
            params=params,
            json=json_body,
            timeout=self._timeout_s,
        )

        if not res.ok:
            raise ApiError(status_code=res.status_code, url=url, body=res.text)

        if res.status_code == 204:
            return None

        return res.json()

    def start_build(self, payload: dict[str, Any]) -> dict[str, Any]:
        return self._request_json("POST", "/build", json_body=payload)

    def wait_build(self, job_name: str, timeout_s: int = 1800) -> dict[str, Any]:
        return self._request_json("POST", f"/build/{job_name}/wait", params={"timeout": timeout_s})

    def resolve_digest(self, image_name: str, tag: str) -> str:
        result = self._request_json("GET", f"/registry/{image_name}/digest", params={"tag": tag})
        build_id = result.get("buildId") if isinstance(result, dict) else None
        if not build_id or not isinstance(build_id, str):
            raise RuntimeError("Unexpected response when resolving digest")
        return build_id
