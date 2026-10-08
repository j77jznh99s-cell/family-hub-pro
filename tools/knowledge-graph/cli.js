#!/usr/bin/env node
// CLI for the workspace knowledge graph. Any agent (or the owner) can read/write it with plain
// `node tools/knowledge-graph/cli.js <command> ...` - no API, no server, works from any session.
// See vault/Playbooks/Knowledge Graph.md for the schema and usage examples.
'use strict';

const path = require('node:path');
const graphLib = require('./graph');

const DEFAULT_GRAPH_PATH = path.join(__dirname, '..', '..', 'vault', 'Memory', 'knowledge-graph.json');

function parseFlags(args) {
  const flags = {};
  const positional = [];
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg.startsWith('--')) {
      const key = arg.slice(2);
      const next = args[i + 1];
      if (next !== undefined && !next.startsWith('--')) {
        flags[key] = next;
        i++;
      } else {
        flags[key] = true;
      }
    } else {
      positional.push(arg);
    }
  }
  return { flags, positional };
}

function parseData(raw) {
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch (err) {
    throw new Error(`--data must be valid JSON: ${err.message}`);
  }
}

function printJSON(value) {
  console.log(JSON.stringify(value, null, 2));
}

function main() {
  const [, , command, ...rest] = process.argv;
  const { flags, positional } = parseFlags(rest);
  const graphPath = flags.file || DEFAULT_GRAPH_PATH;
  const graph = graphLib.load(graphPath);

  switch (command) {
    case 'add-node': {
      const node = graphLib.addNode(graph, {
        id: flags.id,
        type: flags.type,
        label: flags.label,
        data: parseData(flags.data),
      });
      graphLib.save(graphPath, graph);
      printJSON(node);
      break;
    }
    case 'add-edge': {
      const edge = graphLib.addEdge(graph, {
        from: flags.from,
        to: flags.to,
        type: flags.type,
        data: parseData(flags.data),
      });
      graphLib.save(graphPath, graph);
      printJSON(edge);
      break;
    }
    case 'get': {
      printJSON(graphLib.getNode(graph, positional[0]));
      break;
    }
    case 'find': {
      printJSON(graphLib.findNodes(graph, { type: flags.type, labelContains: flags.label }));
      break;
    }
    case 'neighbors': {
      printJSON(
        graphLib.neighbors(graph, positional[0], {
          direction: flags.direction || 'out',
          edgeType: flags['edge-type'],
        })
      );
      break;
    }
    case 'traverse': {
      const edgeTypes = (flags.path || '').split(',').map((s) => s.trim()).filter(Boolean);
      printJSON(graphLib.traversePath(graph, positional[0], edgeTypes));
      break;
    }
    case 'stats': {
      printJSON(graphLib.stats(graph));
      break;
    }
    default: {
      console.error(`Unknown command: ${command || '(none)'}

Usage:
  node cli.js add-node --type <type> --label <label> [--id <id>] [--data '<json>']
  node cli.js add-edge --from <id> --to <id> --type <type> [--data '<json>']
  node cli.js get <id>
  node cli.js find [--type <type>] [--label <substring>]
  node cli.js neighbors <id> [--direction out|in|both] [--edge-type <type>]
  node cli.js traverse <startId> --path <edgeType1,edgeType2,...>
  node cli.js stats
  (all commands accept --file <path> to use a graph file other than the default vault one)`);
      process.exitCode = 1;
    }
  }
}

main();
