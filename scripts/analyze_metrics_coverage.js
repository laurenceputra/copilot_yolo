#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const EVENT_PATTERN = /\bemit_metric\s+["']([A-Za-z0-9_.-]+)["']/g;

function parseArgs(argv) {
  const args = {
    manifest: "metrics/coverage_manifest.json",
    root: ".",
    format: "text",
    failOnIssues: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--manifest") {
      args.manifest = argv[index + 1];
      index += 1;
    } else if (arg === "--root") {
      args.root = argv[index + 1];
      index += 1;
    } else if (arg === "--format") {
      args.format = argv[index + 1];
      index += 1;
    } else if (arg === "--fail-on-issues") {
      args.failOnIssues = true;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (!["text", "json"].includes(args.format)) {
    throw new Error(`unsupported format: ${args.format}`);
  }

  return args;
}

function loadManifest(root, manifestPath) {
  const manifestFile = path.resolve(root, manifestPath);
  const manifest = JSON.parse(fs.readFileSync(manifestFile, "utf8"));
  if (!manifest.sources || !manifest.flows) {
    throw new Error("manifest must contain 'sources' and 'flows'");
  }
  return manifest;
}

function scanSources(root, sources) {
  const observed = new Map();

  for (const relativePath of sources) {
    const sourcePath = path.resolve(root, relativePath);
    if (!fs.existsSync(sourcePath)) {
      throw new Error(`source file not found: ${relativePath}`);
    }

    const lines = fs.readFileSync(sourcePath, "utf8").split(/\r?\n/);
    lines.forEach((line, lineIndex) => {
      if (line.trimStart().startsWith("#")) {
        return;
      }
      EVENT_PATTERN.lastIndex = 0;
      let match = EVENT_PATTERN.exec(line);
      while (match) {
        const eventId = match[1];
        const occurrence = {
          file: relativePath,
          line: lineIndex + 1,
          snippet: line.trim(),
        };
        if (!observed.has(eventId)) {
          observed.set(eventId, []);
        }
        observed.get(eventId).push(occurrence);
        match = EVENT_PATTERN.exec(line);
      }
    });
  }

  return observed;
}

function analyzeManifest(manifest, observed) {
  const manifestDuplicates = [];
  const expectedLookup = new Map();
  const flowReports = [];
  let missingCount = 0;
  let ambiguousCount = 0;

  for (const flow of manifest.flows) {
    let flowStatus = "covered";
    const eventReports = [];

    for (const expected of flow.expected_events) {
      const eventId = expected.id;
      const expectedFile = expected.file;

      if (expectedLookup.has(eventId)) {
        manifestDuplicates.push({
          id: eventId,
          first_file: expectedLookup.get(eventId).file,
          second_file: expectedFile,
        });
        flowStatus = "failing";
        continue;
      }

      expectedLookup.set(eventId, expected);
      const matches = observed.get(eventId) || [];
      const matchingFileHits = matches.filter((match) => match.file === expectedFile);

      let status;
      let reason;
      if (matches.length === 0) {
        status = "missing";
        reason = "event not found";
        missingCount += 1;
        flowStatus = "failing";
      } else if (matches.length === 1 && matchingFileHits.length === 1) {
        status = "covered";
        reason = "event found exactly once in expected file";
      } else {
        status = "ambiguous";
        reason = "event found multiple times or outside expected file";
        ambiguousCount += 1;
        flowStatus = "failing";
      }

      eventReports.push({
        id: eventId,
        expected_file: expectedFile,
        status,
        reason,
        matches,
      });
    }

    flowReports.push({
      id: flow.id,
      description: flow.description || "",
      status: flowStatus,
      events: eventReports,
    });
  }

  const untrackedEvents = Array.from(observed.entries())
    .filter(([eventId]) => !expectedLookup.has(eventId))
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([eventId, matches]) => ({ id: eventId, matches }));

  const coveredFlows = flowReports.filter((flow) => flow.status === "covered").length;
  const summary = {
    flow_count: flowReports.length,
    covered_flows: coveredFlows,
    failing_flows: flowReports.length - coveredFlows,
    missing_events: missingCount,
    ambiguous_events: ambiguousCount,
    untracked_events: untrackedEvents.length,
    manifest_duplicates: manifestDuplicates.length,
  };

  const status =
    summary.missing_events ||
    summary.ambiguous_events ||
    summary.untracked_events ||
    summary.manifest_duplicates
      ? "fail"
      : "ok";

  return {
    status,
    summary,
    flows: flowReports,
    manifest_duplicates: manifestDuplicates,
    untracked_events: untrackedEvents,
  };
}

function formatText(report) {
  const lines = [
    `Metrics coverage: ${report.status.toUpperCase()}`,
    `Flows: ${report.summary.covered_flows}/${report.summary.flow_count} covered, ${report.summary.failing_flows} failing`,
    `Issues: ${report.summary.missing_events} missing, ${report.summary.ambiguous_events} ambiguous, ${report.summary.untracked_events} untracked, ${report.summary.manifest_duplicates} manifest duplicates`,
    "",
  ];

  for (const flow of report.flows) {
    const marker = flow.status === "covered" ? "OK" : "FAIL";
    lines.push(`[${marker}] ${flow.id}: ${flow.description}`);
    for (const event of flow.events) {
      const eventMarker = {
        covered: "OK",
        missing: "MISS",
        ambiguous: "AMB",
      }[event.status];
      const locations =
        event.matches.length > 0
          ? event.matches.map((match) => `${match.file}:${match.line}`).join(", ")
          : "not found";
      lines.push(`  - [${eventMarker}] ${event.id} -> ${event.expected_file} (${locations})`);
    }
    lines.push("");
  }

  if (report.manifest_duplicates.length > 0) {
    lines.push("Manifest duplicates:");
    for (const duplicate of report.manifest_duplicates) {
      lines.push(
        `  - ${duplicate.id} declared in both ${duplicate.first_file} and ${duplicate.second_file}`
      );
    }
    lines.push("");
  }

  if (report.untracked_events.length > 0) {
    lines.push("Untracked events:");
    for (const event of report.untracked_events) {
      const locations = event.matches
        .map((match) => `${match.file}:${match.line}`)
        .join(", ");
      lines.push(`  - ${event.id} (${locations})`);
    }
    lines.push("");
  }

  return `${lines.join("\n").trimEnd()}\n`;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const manifest = loadManifest(args.root, args.manifest);
  const observed = scanSources(args.root, manifest.sources);
  const report = analyzeManifest(manifest, observed);

  if (args.format === "json") {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(formatText(report));
  }

  if (args.failOnIssues && report.status !== "ok") {
    process.exitCode = 1;
  }
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exit(2);
}
