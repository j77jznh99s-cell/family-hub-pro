// Minimal file-based knowledge graph: nodes + typed edges, persisted as one JSON file.
// No server, no new dependency - read/written directly by agents via the CLI in this folder,
// kept in the vault (vault/Memory/knowledge-graph.json) so it's git-tracked like everything else.
'use strict';

const fs = require('node:fs');
const path = require('node:path');

function emptyGraph() {
  return { nodes: {}, edges: [] };
}

function load(filePath) {
  if (!fs.existsSync(filePath)) return emptyGraph();
  const raw = fs.readFileSync(filePath, 'utf8').trim();
  if (!raw) return emptyGraph();
  const parsed = JSON.parse(raw);
  return { nodes: parsed.nodes || {}, edges: parsed.edges || [] };
}

function save(filePath, graph) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(graph, null, 2) + '\n', 'utf8');
}

function slugify(text) {
  return String(text)
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function addNode(graph, { id, type, label, data = {} }) {
  if (!type) throw new Error('addNode requires a type');
  if (!label) throw new Error('addNode requires a label');
  const nodeId = id || `${slugify(type)}:${slugify(label)}`;
  const now = new Date().toISOString();
  const existing = graph.nodes[nodeId];
  graph.nodes[nodeId] = {
    id: nodeId,
    type,
    label,
    data: { ...(existing ? existing.data : {}), ...data },
    createdAt: existing ? existing.createdAt : now,
    updatedAt: now,
  };
  return graph.nodes[nodeId];
}

function getNode(graph, id) {
  return graph.nodes[id] || null;
}

function findNodes(graph, { type, labelContains } = {}) {
  return Object.values(graph.nodes).filter((n) => {
    if (type && n.type !== type) return false;
    if (labelContains && !n.label.toLowerCase().includes(labelContains.toLowerCase())) return false;
    return true;
  });
}

function addEdge(graph, { from, to, type, data = {} }) {
  if (!graph.nodes[from]) throw new Error(`addEdge: unknown "from" node ${from}`);
  if (!graph.nodes[to]) throw new Error(`addEdge: unknown "to" node ${to}`);
  if (!type) throw new Error('addEdge requires a type');
  const edge = { from, to, type, data, createdAt: new Date().toISOString() };
  graph.edges.push(edge);
  return edge;
}

// direction: 'out' (edges where id is "from"), 'in' (id is "to"), or 'both'. Optional edgeType filter.
function neighbors(graph, id, { direction = 'out', edgeType } = {}) {
  return graph.edges
    .filter((e) => {
      if (edgeType && e.type !== edgeType) return false;
      if (direction === 'out') return e.from === id;
      if (direction === 'in') return e.to === id;
      return e.from === id || e.to === id;
    })
    .map((e) => {
      const neighborId = e.from === id ? e.to : e.from;
      return { edge: e, node: graph.nodes[neighborId] || null };
    });
}

// Follows a chain of edge types hop by hop, breadth-first, e.g. traversePath(g, 'muscle:triceps',
// ['worked_out_on', 'includes_exercise']) walks triceps -> dates -> exercises and returns the
// final layer of nodes (deduped). Mirrors the "node -> relationship -> node" lookup pattern.
function traversePath(graph, startId, edgeTypes) {
  let frontier = [startId];
  for (const edgeType of edgeTypes) {
    const nextIds = new Set();
    for (const id of frontier) {
      for (const { node } of neighbors(graph, id, { direction: 'out', edgeType })) {
        if (node) nextIds.add(node.id);
      }
    }
    frontier = [...nextIds];
    if (frontier.length === 0) break;
  }
  return frontier.map((id) => graph.nodes[id]).filter(Boolean);
}

function stats(graph) {
  const nodesByType = {};
  for (const n of Object.values(graph.nodes)) {
    nodesByType[n.type] = (nodesByType[n.type] || 0) + 1;
  }
  const edgesByType = {};
  for (const e of graph.edges) {
    edgesByType[e.type] = (edgesByType[e.type] || 0) + 1;
  }
  return {
    nodeCount: Object.keys(graph.nodes).length,
    edgeCount: graph.edges.length,
    nodesByType,
    edgesByType,
  };
}

module.exports = {
  emptyGraph,
  load,
  save,
  addNode,
  getNode,
  findNodes,
  addEdge,
  neighbors,
  traversePath,
  stats,
  slugify,
};
