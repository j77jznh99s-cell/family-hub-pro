const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

const graphLib = require('../tools/knowledge-graph/graph');

function tmpGraphPath() {
  return path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'kg-test-')), 'graph.json');
}

test('addNode creates a node with a derived id and merges data on repeat calls', () => {
  const graph = graphLib.emptyGraph();
  const first = graphLib.addNode(graph, { type: 'project', label: 'Clip Studio', data: { status: 'active' } });
  assert.equal(first.id, 'project:clip-studio');
  assert.equal(first.label, 'Clip Studio');
  assert.deepEqual(first.data, { status: 'active' });

  const second = graphLib.addNode(graph, { type: 'project', label: 'Clip Studio', data: { owner: 'you' } });
  assert.equal(second.id, first.id);
  assert.deepEqual(second.data, { status: 'active', owner: 'you' });
  assert.equal(Object.keys(graph.nodes).length, 1);
});

test('addEdge rejects edges to/from unknown nodes', () => {
  const graph = graphLib.emptyGraph();
  graphLib.addNode(graph, { id: 'a', type: 'x', label: 'A' });
  assert.throws(() => graphLib.addEdge(graph, { from: 'a', to: 'missing', type: 'relates_to' }));
  assert.throws(() => graphLib.addEdge(graph, { from: 'missing', to: 'a', type: 'relates_to' }));
});

test('neighbors respects direction and edge type filters', () => {
  const graph = graphLib.emptyGraph();
  graphLib.addNode(graph, { id: 'owner', type: 'person', label: 'Owner' });
  graphLib.addNode(graph, { id: 'proj1', type: 'project', label: 'Proj 1' });
  graphLib.addNode(graph, { id: 'proj2', type: 'project', label: 'Proj 2' });
  graphLib.addEdge(graph, { from: 'owner', to: 'proj1', type: 'owns' });
  graphLib.addEdge(graph, { from: 'owner', to: 'proj2', type: 'owns' });
  graphLib.addEdge(graph, { from: 'proj1', to: 'proj2', type: 'blocks' });

  const outFromOwner = graphLib.neighbors(graph, 'owner', { direction: 'out' });
  assert.equal(outFromOwner.length, 2);

  const ownsOnly = graphLib.neighbors(graph, 'owner', { direction: 'out', edgeType: 'owns' });
  assert.equal(ownsOnly.length, 2);
  assert.ok(ownsOnly.every((n) => n.edge.type === 'owns'));

  const intoProj2 = graphLib.neighbors(graph, 'proj2', { direction: 'in' });
  assert.equal(intoProj2.length, 2);
});

test('traversePath follows a multi-hop chain and dedupes the final layer', () => {
  const graph = graphLib.emptyGraph();
  graphLib.addNode(graph, { id: 'triceps', type: 'muscle', label: 'Triceps' });
  graphLib.addNode(graph, { id: 'date1', type: 'date', label: '2026-10-01' });
  graphLib.addNode(graph, { id: 'date2', type: 'date', label: '2026-10-03' });
  graphLib.addNode(graph, { id: 'dips', type: 'exercise', label: 'Dips' });
  graphLib.addNode(graph, { id: 'pushdowns', type: 'exercise', label: 'Pushdowns' });

  graphLib.addEdge(graph, { from: 'triceps', to: 'date1', type: 'worked_out_on' });
  graphLib.addEdge(graph, { from: 'triceps', to: 'date2', type: 'worked_out_on' });
  graphLib.addEdge(graph, { from: 'date1', to: 'dips', type: 'includes_exercise' });
  graphLib.addEdge(graph, { from: 'date2', to: 'dips', type: 'includes_exercise' });
  graphLib.addEdge(graph, { from: 'date2', to: 'pushdowns', type: 'includes_exercise' });

  const exercises = graphLib.traversePath(graph, 'triceps', ['worked_out_on', 'includes_exercise']);
  const labels = exercises.map((n) => n.label).sort();
  assert.deepEqual(labels, ['Dips', 'Pushdowns']);
});

test('traversePath returns an empty list when a hop has no matching edges', () => {
  const graph = graphLib.emptyGraph();
  graphLib.addNode(graph, { id: 'a', type: 'x', label: 'A' });
  assert.deepEqual(graphLib.traversePath(graph, 'a', ['nonexistent']), []);
});

test('findNodes filters by type and label substring (case-insensitive)', () => {
  const graph = graphLib.emptyGraph();
  graphLib.addNode(graph, { type: 'project', label: 'Clip Studio' });
  graphLib.addNode(graph, { type: 'project', label: 'Family Hub' });
  graphLib.addNode(graph, { type: 'decision', label: 'Pause StarNet' });

  assert.equal(graphLib.findNodes(graph, { type: 'project' }).length, 2);
  assert.equal(graphLib.findNodes(graph, { labelContains: 'clip' }).length, 1);
  assert.equal(graphLib.findNodes(graph, { type: 'project', labelContains: 'hub' }).length, 1);
});

test('stats counts nodes and edges by type', () => {
  const graph = graphLib.emptyGraph();
  graphLib.addNode(graph, { id: 'a', type: 'project', label: 'A' });
  graphLib.addNode(graph, { id: 'b', type: 'project', label: 'B' });
  graphLib.addNode(graph, { id: 'c', type: 'decision', label: 'C' });
  graphLib.addEdge(graph, { from: 'a', to: 'c', type: 'has_decision' });

  const s = graphLib.stats(graph);
  assert.equal(s.nodeCount, 3);
  assert.equal(s.edgeCount, 1);
  assert.deepEqual(s.nodesByType, { project: 2, decision: 1 });
  assert.deepEqual(s.edgesByType, { has_decision: 1 });
});

test('save/load round-trips a graph through disk', () => {
  const filePath = tmpGraphPath();
  const graph = graphLib.emptyGraph();
  graphLib.addNode(graph, { id: 'a', type: 'project', label: 'A' });
  graphLib.addNode(graph, { id: 'b', type: 'project', label: 'B' });
  graphLib.addEdge(graph, { from: 'a', to: 'b', type: 'relates_to' });
  graphLib.save(filePath, graph);

  const loaded = graphLib.load(filePath);
  assert.deepEqual(Object.keys(loaded.nodes).sort(), ['a', 'b']);
  assert.equal(loaded.edges.length, 1);
  assert.equal(loaded.edges[0].type, 'relates_to');
});

test('load returns an empty graph for a missing file', () => {
  const missingPath = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'kg-test-')), 'does-not-exist.json');
  const graph = graphLib.load(missingPath);
  assert.deepEqual(graph, { nodes: {}, edges: [] });
});
