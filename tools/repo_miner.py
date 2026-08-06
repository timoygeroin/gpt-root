#!/usr/bin/env python3
"""Mine a bounded, relevant slice of GitHub for MondayID architecture candidates.

This does not pretend to inspect every GitHub repository. It searches a versioned
query map, deduplicates candidates, scores evidence that can be checked cheaply,
and emits a review queue for deeper human/agent inspection.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

GITHUB_API = "https://api.github.com"
USER_AGENT = "MondayID-Repo-Miner/0.1"


@dataclass(frozen=True)
class Candidate:
    full_name: str
    category: str
    description: str
    html_url: str
    stars: int
    forks: int
    open_issues: int
    language: str | None
    license: str | None
    topics: list[str]
    archived: bool
    fork: bool
    updated_at: str
    score: float
    matched_queries: list[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--queries", default="research/repo_queries.json")
    parser.add_argument("--output-json", default="artifacts/repo-mining.json")
    parser.add_argument("--output-md", default="artifacts/repo-mining.md")
    parser.add_argument("--per-query", type=int, default=10)
    parser.add_argument("--top-per-category", type=int, default=12)
    return parser.parse_args()


def github_get(path: str, token: str | None) -> dict[str, Any]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": USER_AGENT,
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(f"{GITHUB_API}{path}", headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API {exc.code}: {body[:500]}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"GitHub API unavailable: {exc.reason}") from exc


def age_days(updated_at: str) -> float:
    updated = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
    return max(0.0, (datetime.now(timezone.utc) - updated).total_seconds() / 86400)


def score_item(item: dict[str, Any]) -> float:
    stars = int(item.get("stargazers_count") or 0)
    forks = int(item.get("forks_count") or 0)
    issues = int(item.get("open_issues_count") or 0)
    freshness = math.exp(-age_days(item["updated_at"]) / 365.0)
    license_bonus = 5.0 if item.get("license") else 0.0
    topic_bonus = min(len(item.get("topics") or []), 10) * 0.35
    maintenance_signal = min(math.log10(forks + 1), 4.0) * 1.5
    issue_penalty = min(math.log10(issues + 1), 4.0) * 0.35
    archived_penalty = 40.0 if item.get("archived") else 0.0
    fork_penalty = 8.0 if item.get("fork") else 0.0

    return round(
        min(math.log10(stars + 1), 6.0) * 10.0
        + freshness * 20.0
        + license_bonus
        + topic_bonus
        + maintenance_signal
        - issue_penalty
        - archived_penalty
        - fork_penalty,
        3,
    )


def search_query(query: str, per_query: int, token: str | None) -> list[dict[str, Any]]:
    encoded = urllib.parse.urlencode(
        {"q": query, "sort": "stars", "order": "desc", "per_page": per_query}
    )
    payload = github_get(f"/search/repositories?{encoded}", token)
    return list(payload.get("items") or [])


def mine(
    query_map: dict[str, list[str]], per_query: int, token: str | None
) -> list[Candidate]:
    merged: dict[tuple[str, str], dict[str, Any]] = {}

    for category, queries in query_map.items():
        for query in queries:
            for item in search_query(query, per_query, token):
                key = (category, item["full_name"].lower())
                if key not in merged:
                    merged[key] = {
                        "item": item,
                        "queries": [],
                    }
                merged[key]["queries"].append(query)
            time.sleep(0.15)

    candidates: list[Candidate] = []
    for (category, _), value in merged.items():
        item = value["item"]
        license_data = item.get("license") or {}
        candidates.append(
            Candidate(
                full_name=item["full_name"],
                category=category,
                description=(item.get("description") or "").strip(),
                html_url=item["html_url"],
                stars=int(item.get("stargazers_count") or 0),
                forks=int(item.get("forks_count") or 0),
                open_issues=int(item.get("open_issues_count") or 0),
                language=item.get("language"),
                license=license_data.get("spdx_id"),
                topics=sorted(item.get("topics") or []),
                archived=bool(item.get("archived")),
                fork=bool(item.get("fork")),
                updated_at=item["updated_at"],
                score=score_item(item),
                matched_queries=sorted(set(value["queries"])),
            )
        )

    return sorted(candidates, key=lambda candidate: candidate.score, reverse=True)


def select_top(candidates: list[Candidate], top_per_category: int) -> list[Candidate]:
    counts: dict[str, int] = {}
    selected: list[Candidate] = []
    for candidate in candidates:
        count = counts.get(candidate.category, 0)
        if count >= top_per_category:
            continue
        selected.append(candidate)
        counts[candidate.category] = count + 1
    return selected


def write_json(path: Path, candidates: list[Candidate], query_map: dict[str, list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "method": "bounded GitHub Search API mining; results require deep review",
        "categories": sorted(query_map),
        "candidate_count": len(candidates),
        "candidates": [asdict(candidate) for candidate in candidates],
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def escape_md(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def write_markdown(path: Path, candidates: list[Candidate]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# MondayID GitHub Mining Snapshot",
        "",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        "",
        "> This is a discovery queue, not a trust verdict. Every candidate still needs license, security, architecture, provenance and behavior review.",
        "",
    ]
    categories = sorted({candidate.category for candidate in candidates})
    for category in categories:
        lines.extend(
            [
                f"## {category}",
                "",
                "| Repository | Score | Stars | Updated | License | Description |",
                "|---|---:|---:|---|---|---|",
            ]
        )
        for candidate in candidates:
            if candidate.category != category:
                continue
            lines.append(
                "| [{name}]({url}) | {score:.3f} | {stars} | {updated} | {license} | {description} |".format(
                    name=escape_md(candidate.full_name),
                    url=candidate.html_url,
                    score=candidate.score,
                    stars=candidate.stars,
                    updated=candidate.updated_at[:10],
                    license=candidate.license or "UNKNOWN",
                    description=escape_md(candidate.description[:180]),
                )
            )
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    if args.per_query < 1 or args.per_query > 100:
        raise ValueError("--per-query must be between 1 and 100")
    if args.top_per_category < 1:
        raise ValueError("--top-per-category must be positive")

    query_path = Path(args.queries)
    query_map = json.loads(query_path.read_text(encoding="utf-8"))
    if not isinstance(query_map, dict) or not query_map:
        raise ValueError("query map must be a non-empty object")

    token = os.environ.get("GITHUB_TOKEN")
    candidates = mine(query_map, args.per_query, token)
    selected = select_top(candidates, args.top_per_category)
    write_json(Path(args.output_json), selected, query_map)
    write_markdown(Path(args.output_md), selected)
    print(f"MINING_COMPLETE candidates={len(selected)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        print(f"MINING_FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)
