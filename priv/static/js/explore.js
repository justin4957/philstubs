(function () {
  "use strict";

  // --- Constants ---

  var API_BASE = "/api/explore";

  var LEVEL_COLORS = {
    federal: "#1565c0",
    state: "#2e7d32",
    county: "#e65100",
    municipal: "#6a1b9a",
  };

  var EDGE_COLORS = {
    references: "#333",
    amends: "#e65100",
    supersedes: "#c62828",
    implements: "#1565c0",
    delegates: "#6a1b9a",
    similar_to: "#999",
  };

  var EDGE_DASH = {
    references: null,
    amends: "4,2",
    supersedes: "8,4",
    implements: "2,2",
    delegates: "6,2",
    similar_to: "1,3",
  };

  var MIN_NODE_RADIUS = 6;
  var MAX_NODE_RADIUS = 24;

  // --- State ---

  var graphState = {
    nodes: [],
    edges: [],
    nodeMap: new Map(),
    edgeSet: new Set(),
    selectedNodeId: null,
    pathHighlight: new Set(),
    pathNodeHighlight: new Set(),
    visibleEdgeTypes: new Set([
      "references",
      "amends",
      "supersedes",
      "implements",
      "delegates",
      "similar_to",
    ]),
    depth: 1,
    maxDegree: 1,
  };

  var svg, simulation, graphGroup, linkGroup, nodeGroup, labelGroup;
  var zoomBehavior;
  var containerWidth, containerHeight;

  // --- API Layer ---

  function handleResponse(response) {
    if (!response.ok) {
      throw new Error("API error: " + response.status);
    }
    return response.json();
  }

  function fetchNode(nodeId) {
    return fetch(API_BASE + "/node/" + encodeURIComponent(nodeId)).then(
      handleResponse
    );
  }

  function fetchExpand(nodeId, edgeTypes, depth) {
    var params = new URLSearchParams();
    if (edgeTypes) params.set("edge_types", edgeTypes);
    params.set("depth", depth.toString());
    return fetch(
      API_BASE + "/expand/" + encodeURIComponent(nodeId) + "?" + params
    ).then(handleResponse);
  }

  function fetchPath(fromId, toId) {
    return fetch(
      API_BASE +
        "/path/" +
        encodeURIComponent(fromId) +
        "/" +
        encodeURIComponent(toId)
    ).then(handleResponse);
  }

  function fetchCluster(topicSlug, limit, minSimilarity) {
    var params = new URLSearchParams();
    params.set("limit", limit.toString());
    params.set("min_similarity", minSimilarity.toString());
    return fetch(
      API_BASE + "/cluster/" + encodeURIComponent(topicSlug) + "?" + params
    ).then(handleResponse);
  }

  function searchLegislation(query) {
    return fetch("/api/search?q=" + encodeURIComponent(query)).then(
      handleResponse
    );
  }

  // --- Graph Data Management ---

  function mergeNodes(newNodes) {
    newNodes.forEach(function (apiNode) {
      if (graphState.nodeMap.has(apiNode.id)) return;
      var graphNode = {
        id: apiNode.id,
        label: apiNode.label,
        level: apiNode.level,
        status: apiNode.status,
        date: apiNode.date,
        metadata: apiNode.metadata,
        node_type: apiNode.type,
        degree: 0,
        x: containerWidth / 2 + (Math.random() - 0.5) * 100,
        y: containerHeight / 2 + (Math.random() - 0.5) * 100,
      };
      graphState.nodes.push(graphNode);
      graphState.nodeMap.set(apiNode.id, graphNode);
    });
  }

  function mergeEdges(newEdges) {
    newEdges.forEach(function (apiEdge) {
      var edgeKey = apiEdge.source + ":" + apiEdge.target + ":" + apiEdge.type;
      if (graphState.edgeSet.has(edgeKey)) return;
      if (
        !graphState.nodeMap.has(apiEdge.source) ||
        !graphState.nodeMap.has(apiEdge.target)
      )
        return;
      var graphEdge = {
        source: apiEdge.source,
        target: apiEdge.target,
        edge_type: apiEdge.type,
        weight: apiEdge.weight,
        metadata: apiEdge.metadata,
      };
      graphState.edges.push(graphEdge);
      graphState.edgeSet.add(edgeKey);
    });
  }

  function computeNodeDegrees() {
    graphState.nodes.forEach(function (node) {
      node.degree = 0;
    });
    graphState.edges.forEach(function (edge) {
      var sourceId =
        typeof edge.source === "object" ? edge.source.id : edge.source;
      var targetId =
        typeof edge.target === "object" ? edge.target.id : edge.target;
      var sourceNode = graphState.nodeMap.get(sourceId);
      var targetNode = graphState.nodeMap.get(targetId);
      if (sourceNode) sourceNode.degree++;
      if (targetNode) targetNode.degree++;
    });
    graphState.maxDegree = Math.max(
      1,
      d3.max(graphState.nodes, function (d) {
        return d.degree;
      }) || 1
    );
  }

  function nodeRadius(node) {
    return (
      MIN_NODE_RADIUS +
      (node.degree / graphState.maxDegree) * (MAX_NODE_RADIUS - MIN_NODE_RADIUS)
    );
  }

  function levelColor(level) {
    var kind = level && level.kind ? level.kind : "federal";
    return LEVEL_COLORS[kind] || LEVEL_COLORS.federal;
  }

  function clearGraph() {
    graphState.nodes = [];
    graphState.edges = [];
    graphState.nodeMap.clear();
    graphState.edgeSet.clear();
    graphState.pathHighlight.clear();
    graphState.pathNodeHighlight.clear();
    graphState.selectedNodeId = null;
  }

  // --- D3 Visualization ---

  function initializeSvg() {
    var container = document.getElementById("explore-graph");
    var rect = container.getBoundingClientRect();
    containerWidth = rect.width || 800;
    containerHeight = Math.max(rect.height, 500);

    svg = d3
      .select("#explore-graph")
      .append("svg")
      .attr("width", "100%")
      .attr("height", "100%")
      .attr(
        "viewBox",
        "0 0 " + containerWidth + " " + containerHeight
      );

    // Arrow marker for directed edges
    svg
      .append("defs")
      .append("marker")
      .attr("id", "explore-arrowhead")
      .attr("viewBox", "0 -5 10 10")
      .attr("refX", 20)
      .attr("refY", 0)
      .attr("markerWidth", 6)
      .attr("markerHeight", 6)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M0,-5L10,0L0,5")
      .attr("fill", "#999");

    zoomBehavior = d3
      .zoom()
      .scaleExtent([0.1, 8])
      .on("zoom", function (event) {
        graphGroup.attr("transform", event.transform);
      });

    svg.call(zoomBehavior);

    graphGroup = svg.append("g").attr("class", "explore-graph-group");
    linkGroup = graphGroup.append("g").attr("class", "explore-links");
    nodeGroup = graphGroup.append("g").attr("class", "explore-nodes");
    labelGroup = graphGroup.append("g").attr("class", "explore-labels");
  }

  function initializeSimulation() {
    simulation = d3
      .forceSimulation(graphState.nodes)
      .force(
        "link",
        d3
          .forceLink(graphState.edges)
          .id(function (d) {
            return d.id;
          })
          .distance(100)
      )
      .force("charge", d3.forceManyBody().strength(-200))
      .force(
        "center",
        d3.forceCenter(containerWidth / 2, containerHeight / 2)
      )
      .force(
        "collision",
        d3.forceCollide().radius(function (d) {
          return nodeRadius(d) + 4;
        })
      )
      .on("tick", onTick);
  }

  function updateGraph() {
    // Links
    var linkSelection = linkGroup
      .selectAll("line")
      .data(graphState.edges, function (d) {
        var sourceId = typeof d.source === "object" ? d.source.id : d.source;
        var targetId = typeof d.target === "object" ? d.target.id : d.target;
        return sourceId + ":" + targetId + ":" + d.edge_type;
      });

    linkSelection.exit().remove();

    var linkEnter = linkSelection
      .enter()
      .append("line")
      .attr("class", "explore-edge")
      .attr("stroke", function (d) {
        return EDGE_COLORS[d.edge_type] || "#999";
      })
      .attr("stroke-width", function (d) {
        return Math.max(1, d.weight * 3);
      })
      .attr("stroke-dasharray", function (d) {
        return EDGE_DASH[d.edge_type] || null;
      })
      .attr("marker-end", function (d) {
        return d.edge_type !== "similar_to" ? "url(#explore-arrowhead)" : null;
      });

    linkGroup.selectAll("line").each(function (d) {
      var el = d3.select(this);
      var edgeKey =
        (typeof d.source === "object" ? d.source.id : d.source) +
        ":" +
        (typeof d.target === "object" ? d.target.id : d.target);
      var isVisible = graphState.visibleEdgeTypes.has(d.edge_type);
      var isHighlighted = graphState.pathHighlight.has(edgeKey);
      el.classed("explore-edge-hidden", !isVisible);
      el.classed("explore-edge-highlighted", isHighlighted);
    });

    // Nodes
    var nodeSelection = nodeGroup
      .selectAll("circle")
      .data(graphState.nodes, function (d) {
        return d.id;
      });

    nodeSelection.exit().remove();

    var nodeEnter = nodeSelection
      .enter()
      .append("circle")
      .attr("class", "explore-node")
      .attr("r", function (d) {
        return nodeRadius(d);
      })
      .attr("fill", function (d) {
        return levelColor(d.level);
      })
      .on("click", onNodeClick)
      .on("dblclick", onNodeDoubleClick)
      .call(
        d3
          .drag()
          .on("start", dragStarted)
          .on("drag", dragged)
          .on("end", dragEnded)
      );

    nodeGroup.selectAll("circle").each(function (d) {
      var el = d3.select(this);
      el.attr("r", nodeRadius(d));
      el.classed(
        "explore-node-selected",
        d.id === graphState.selectedNodeId
      );
      el.classed(
        "explore-node-in-path",
        graphState.pathNodeHighlight.has(d.id)
      );
    });

    // Labels
    var labelSelection = labelGroup
      .selectAll("text")
      .data(graphState.nodes, function (d) {
        return d.id;
      });

    labelSelection.exit().remove();

    labelSelection
      .enter()
      .append("text")
      .attr("class", "explore-node-label")
      .attr("dy", function (d) {
        return nodeRadius(d) + 12;
      })
      .text(function (d) {
        return d.label.length > 30 ? d.label.substring(0, 27) + "..." : d.label;
      });

    // Restart simulation
    simulation.nodes(graphState.nodes);
    simulation.force("link").links(graphState.edges);
    simulation.alpha(0.3).restart();
  }

  function onTick() {
    linkGroup
      .selectAll("line")
      .attr("x1", function (d) {
        return d.source.x;
      })
      .attr("y1", function (d) {
        return d.source.y;
      })
      .attr("x2", function (d) {
        return d.target.x;
      })
      .attr("y2", function (d) {
        return d.target.y;
      });

    nodeGroup
      .selectAll("circle")
      .attr("cx", function (d) {
        return d.x;
      })
      .attr("cy", function (d) {
        return d.y;
      });

    labelGroup
      .selectAll("text")
      .attr("x", function (d) {
        return d.x;
      })
      .attr("y", function (d) {
        return d.y;
      });
  }

  // --- Interaction Handlers ---

  function onNodeClick(event, nodeData) {
    event.stopPropagation();
    clearPathHighlight();
    graphState.selectedNodeId = nodeData.id;
    nodeGroup.selectAll("circle").classed("explore-node-selected", function (d) {
      return d.id === graphState.selectedNodeId;
    });
    populateDetailPanel(nodeData);
  }

  function onNodeDoubleClick(event, nodeData) {
    event.stopPropagation();
    event.preventDefault();
    expandNode(nodeData.id);
  }

  function expandNode(nodeId) {
    var edgeTypesParam = Array.from(graphState.visibleEdgeTypes).join(",");
    showNotification("Expanding...");
    fetchExpand(nodeId, edgeTypesParam, graphState.depth)
      .then(function (result) {
        mergeNodes(result.nodes);
        mergeEdges(result.edges);
        computeNodeDegrees();
        updateGraph();
        showNotification("Added " + result.nodes.length + " nodes");
      })
      .catch(function (error) {
        showNotification("Error: " + error.message);
      });
  }

  function loadNodeAndCenter(nodeId) {
    showNotification("Loading node...");
    fetchNode(nodeId)
      .then(function (neighborhood) {
        var allNodes = [neighborhood.node].concat(neighborhood.neighbors);
        mergeNodes(allNodes);
        mergeEdges(neighborhood.edges);
        computeNodeDegrees();
        updateGraph();
        hideEmptyState();
        selectNode(nodeId);
      })
      .catch(function (error) {
        showNotification("Error: " + error.message);
      });
  }

  function selectNode(nodeId) {
    graphState.selectedNodeId = nodeId;
    var node = graphState.nodeMap.get(nodeId);
    if (node) {
      populateDetailPanel(node);
    }
    nodeGroup.selectAll("circle").classed("explore-node-selected", function (d) {
      return d.id === graphState.selectedNodeId;
    });
  }

  function onSearchSubmit() {
    var input = document.getElementById("explore-search-input");
    var query = input.value.trim();
    if (!query) return;
    showNotification("Searching...");
    searchLegislation(query)
      .then(function (results) {
        if (results.items && results.items.length > 0) {
          var firstItem = results.items[0];
          var legislationId = firstItem.legislation
            ? firstItem.legislation.id
            : firstItem.id;
          loadNodeAndCenter(legislationId);
        } else {
          showNotification("No results found");
        }
      })
      .catch(function (error) {
        showNotification("Search error: " + error.message);
      });
  }

  function onFindPath() {
    var fromId = document.getElementById("explore-path-from").value.trim();
    var toId = document.getElementById("explore-path-to").value.trim();
    if (!fromId || !toId) {
      showNotification("Enter both node IDs");
      return;
    }
    showNotification("Finding path...");
    fetchPath(fromId, toId)
      .then(function (result) {
        if (result.distance < 0) {
          showNotification("No path found (unreachable)");
          return;
        }
        mergeNodes(result.path);
        mergeEdges(result.edges);
        computeNodeDegrees();
        highlightPath(result.path, result.edges);
        updateGraph();
        showNotification("Path found: " + result.distance + " hops");
      })
      .catch(function (error) {
        showNotification("Path error: " + error.message);
      });
  }

  function onLoadCluster() {
    var topicSlug = document.getElementById("explore-cluster-input").value.trim();
    if (!topicSlug) {
      showNotification("Enter a topic slug");
      return;
    }
    showNotification("Loading cluster...");
    fetchCluster(topicSlug, 50, 0.3)
      .then(function (result) {
        clearGraph();
        mergeNodes(result.nodes);
        mergeEdges(result.edges);
        computeNodeDegrees();
        updateGraph();
        hideEmptyState();
        showNotification("Loaded: " + result.topic_name + " (" + result.nodes.length + " nodes)");
      })
      .catch(function (error) {
        showNotification("Cluster error: " + error.message);
      });
  }

  function onEdgeFilterChange(edgeType, isChecked) {
    if (isChecked) {
      graphState.visibleEdgeTypes.add(edgeType);
    } else {
      graphState.visibleEdgeTypes.delete(edgeType);
    }
    updateEdgeVisibility();
  }

  function updateEdgeVisibility() {
    linkGroup.selectAll("line").each(function (d) {
      var el = d3.select(this);
      var isVisible = graphState.visibleEdgeTypes.has(d.edge_type);
      el.classed("explore-edge-hidden", !isVisible);
    });
  }

  function highlightPath(pathNodes, pathEdges) {
    clearPathHighlight();
    pathEdges.forEach(function (edge) {
      var sourceId = typeof edge.source === "object" ? edge.source.id : edge.source;
      var targetId = typeof edge.target === "object" ? edge.target.id : edge.target;
      graphState.pathHighlight.add(sourceId + ":" + targetId);
      graphState.pathHighlight.add(targetId + ":" + sourceId);
    });
    pathNodes.forEach(function (node) {
      graphState.pathNodeHighlight.add(node.id);
    });
  }

  function clearPathHighlight() {
    graphState.pathHighlight.clear();
    graphState.pathNodeHighlight.clear();
    linkGroup
      .selectAll("line")
      .classed("explore-edge-highlighted", false);
    nodeGroup
      .selectAll("circle")
      .classed("explore-node-in-path", false);
  }

  // --- Detail Panel ---

  function populateDetailPanel(node) {
    var panel = document.getElementById("explore-detail-panel");
    var levelKind = node.level && node.level.kind ? node.level.kind : "unknown";
    var statusText = typeof node.status === "string" ? node.status : (node.status && node.status.kind ? node.status.kind : "unknown");
    var metadata = node.metadata || {};
    var sponsors = metadata.sponsors || [];
    var topics = metadata.topics || [];
    var sourceId = metadata.source_identifier || "";
    var legislationType = metadata.legislation_type || "";

    var html = "";
    html += '<h3 class="explore-detail-title">' + escapeHtml(node.label) + "</h3>";
    html += '<div class="explore-detail-badges">';
    html += '<span class="badge level-badge">' + escapeHtml(levelKind) + "</span>";
    html += '<span class="badge status-badge">' + escapeHtml(statusText) + "</span>";
    if (legislationType) {
      html += '<span class="badge type-badge">' + escapeHtml(legislationType) + "</span>";
    }
    html += "</div>";

    if (sourceId) {
      html += '<div class="explore-detail-section">';
      html += '<span class="explore-detail-label">Identifier</span>';
      html += '<span class="explore-detail-value">' + escapeHtml(sourceId) + "</span>";
      html += "</div>";
    }

    if (node.date) {
      html += '<div class="explore-detail-section">';
      html += '<span class="explore-detail-label">Introduced</span>';
      html += '<span class="explore-detail-value">' + escapeHtml(node.date) + "</span>";
      html += "</div>";
    }

    if (sponsors.length > 0) {
      html += '<div class="explore-detail-section">';
      html += '<span class="explore-detail-label">Sponsors</span>';
      html += '<span class="explore-detail-value">' + sponsors.map(escapeHtml).join(", ") + "</span>";
      html += "</div>";
    }

    if (topics.length > 0) {
      html += '<div class="explore-detail-section">';
      html += '<span class="explore-detail-label">Topics</span>';
      html += '<div class="explore-detail-topics">';
      topics.forEach(function (topic) {
        html += '<span class="badge">' + escapeHtml(topic) + "</span> ";
      });
      html += "</div></div>";
    }

    html += '<div class="explore-detail-actions">';
    html += '<a href="/legislation/' + encodeURIComponent(node.id) + '" class="explore-action-button">View Full Detail</a>';
    html += '<button class="explore-action-button" onclick="PhilstubsExplorer.expand(\'' + escapeAttr(node.id) + '\')">Expand from Here</button>';
    html += "</div>";

    panel.innerHTML = html;
    panel.classList.add("explore-detail-visible");
  }

  function hideDetailPanel() {
    var panel = document.getElementById("explore-detail-panel");
    panel.classList.remove("explore-detail-visible");
    panel.innerHTML = "";
  }

  function escapeHtml(text) {
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
  }

  function escapeAttr(text) {
    return text.replace(/'/g, "\\'").replace(/"/g, "&quot;");
  }

  // --- Zoom ---

  function zoomIn() {
    svg.transition().duration(300).call(zoomBehavior.scaleBy, 1.3);
  }

  function zoomOut() {
    svg.transition().duration(300).call(zoomBehavior.scaleBy, 0.7);
  }

  function zoomReset() {
    svg
      .transition()
      .duration(300)
      .call(zoomBehavior.transform, d3.zoomIdentity);
  }

  // --- Drag ---

  function dragStarted(event, nodeData) {
    if (!event.active) simulation.alphaTarget(0.3).restart();
    nodeData.fx = nodeData.x;
    nodeData.fy = nodeData.y;
  }

  function dragged(event, nodeData) {
    nodeData.fx = event.x;
    nodeData.fy = event.y;
  }

  function dragEnded(event, nodeData) {
    if (!event.active) simulation.alphaTarget(0);
    nodeData.fx = null;
    nodeData.fy = null;
  }

  // --- Notifications ---

  function showNotification(message) {
    var existing = document.querySelector(".explore-notification");
    if (existing) existing.remove();

    var notification = document.createElement("div");
    notification.className = "explore-notification";
    notification.textContent = message;
    document.body.appendChild(notification);

    setTimeout(function () {
      notification.classList.add("explore-notification-fading");
      setTimeout(function () {
        if (notification.parentNode) notification.remove();
      }, 300);
    }, 2500);
  }

  // --- State Serialization ---

  function serializeGraphState() {
    var nodePositions = {};
    graphState.nodes.forEach(function (node) {
      nodePositions[node.id] = {
        x: node.x,
        y: node.y,
        fx: node.fx,
        fy: node.fy,
      };
    });

    var serializedNodes = graphState.nodes.map(function (node) {
      return {
        id: node.id,
        label: node.label,
        level: node.level,
        status: node.status,
        date: node.date,
        metadata: node.metadata,
        node_type: node.node_type,
      };
    });

    var serializedEdges = graphState.edges.map(function (edge) {
      return {
        source: typeof edge.source === "object" ? edge.source.id : edge.source,
        target: typeof edge.target === "object" ? edge.target.id : edge.target,
        type: edge.edge_type,
        weight: edge.weight,
        metadata: edge.metadata,
      };
    });

    var currentTransform = d3.zoomTransform(svg.node());

    return JSON.stringify({
      nodes: serializedNodes,
      edges: serializedEdges,
      nodePositions: nodePositions,
      selectedNodeId: graphState.selectedNodeId,
      visibleEdgeTypes: Array.from(graphState.visibleEdgeTypes),
      depth: graphState.depth,
      zoom: { k: currentTransform.k, x: currentTransform.x, y: currentTransform.y },
    });
  }

  function deserializeGraphState(jsonString) {
    var data = JSON.parse(jsonString);

    clearGraph();

    // Restore nodes
    if (data.nodes) {
      mergeNodes(data.nodes);
    }

    // Restore positions
    if (data.nodePositions) {
      graphState.nodes.forEach(function (node) {
        var savedPosition = data.nodePositions[node.id];
        if (savedPosition) {
          node.x = savedPosition.x;
          node.y = savedPosition.y;
          node.fx = savedPosition.fx;
          node.fy = savedPosition.fy;
        }
      });
    }

    // Restore edges
    if (data.edges) {
      mergeEdges(data.edges);
    }

    computeNodeDegrees();

    // Restore edge type filters
    if (data.visibleEdgeTypes) {
      graphState.visibleEdgeTypes = new Set(data.visibleEdgeTypes);
      var edgeTypes = ["references", "amends", "supersedes", "implements", "delegates", "similar_to"];
      edgeTypes.forEach(function (edgeType) {
        var checkbox = document.getElementById("explore-edge-filter-" + edgeType);
        if (checkbox) {
          checkbox.checked = graphState.visibleEdgeTypes.has(edgeType);
        }
      });
    }

    // Restore depth
    if (data.depth) {
      graphState.depth = data.depth;
      var depthSelect = document.getElementById("explore-depth-select");
      if (depthSelect) depthSelect.value = data.depth.toString();
    }

    // Restore selection
    graphState.selectedNodeId = data.selectedNodeId || null;

    updateGraph();
    hideEmptyState();

    // Restore zoom transform
    if (data.zoom) {
      var transform = d3.zoomIdentity
        .translate(data.zoom.x, data.zoom.y)
        .scale(data.zoom.k);
      svg.call(zoomBehavior.transform, transform);
    }

    // Select node if one was selected
    if (graphState.selectedNodeId) {
      var selectedNode = graphState.nodeMap.get(graphState.selectedNodeId);
      if (selectedNode) {
        populateDetailPanel(selectedNode);
      }
    }
  }

  // --- Exploration API ---

  function saveExploration(title, description, graphStateJson, isPublic) {
    return fetch("/api/explorations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: title,
        description: description,
        graph_state: graphStateJson,
        is_public: isPublic,
      }),
    }).then(handleResponse);
  }

  function loadExploration(explorationId) {
    return fetch("/api/explorations/" + encodeURIComponent(explorationId)).then(
      handleResponse
    );
  }

  function listExplorations() {
    return fetch("/api/explorations").then(handleResponse);
  }

  function deleteExploration(explorationId) {
    return fetch("/api/explorations/" + encodeURIComponent(explorationId), {
      method: "DELETE",
    }).then(function (response) {
      if (!response.ok && response.status !== 204) {
        throw new Error("API error: " + response.status);
      }
      return null;
    });
  }

  // --- Save/Load UI Handlers ---

  function onSaveClick() {
    var dialog = document.getElementById("explore-save-dialog");
    if (dialog) {
      dialog.classList.toggle("explore-save-dialog-visible");
      // Close list panel if open
      var listPanel = document.getElementById("explore-list-panel");
      if (listPanel) listPanel.classList.remove("explore-list-panel-visible");
    }
  }

  function onSaveConfirm() {
    var titleInput = document.getElementById("explore-save-title");
    var descInput = document.getElementById("explore-save-description");
    var publicCheckbox = document.getElementById("explore-save-public");

    var title = titleInput ? titleInput.value.trim() : "";
    var description = descInput ? descInput.value.trim() : "";
    var isPublic = publicCheckbox ? publicCheckbox.checked : false;

    if (!title) {
      showNotification("Title is required");
      return;
    }

    if (graphState.nodes.length === 0) {
      showNotification("Nothing to save — explore some legislation first");
      return;
    }

    var graphStateJson = serializeGraphState();
    showNotification("Saving...");

    saveExploration(title, description, graphStateJson, isPublic)
      .then(function (result) {
        showNotification("Saved: " + result.title);
        // Close dialog and clear inputs
        var dialog = document.getElementById("explore-save-dialog");
        if (dialog) dialog.classList.remove("explore-save-dialog-visible");
        if (titleInput) titleInput.value = "";
        if (descInput) descInput.value = "";
        if (publicCheckbox) publicCheckbox.checked = false;
      })
      .catch(function (error) {
        showNotification("Save error: " + error.message);
      });
  }

  function onSaveCancel() {
    var dialog = document.getElementById("explore-save-dialog");
    if (dialog) dialog.classList.remove("explore-save-dialog-visible");
  }

  function onLoadClick() {
    var listPanel = document.getElementById("explore-list-panel");
    if (!listPanel) return;

    // Close save dialog if open
    var dialog = document.getElementById("explore-save-dialog");
    if (dialog) dialog.classList.remove("explore-save-dialog-visible");

    if (listPanel.classList.contains("explore-list-panel-visible")) {
      listPanel.classList.remove("explore-list-panel-visible");
      return;
    }

    listPanel.innerHTML = '<p class="explore-list-empty">Loading...</p>';
    listPanel.classList.add("explore-list-panel-visible");

    listExplorations()
      .then(function (result) {
        renderExplorationsList(listPanel, result.explorations || []);
      })
      .catch(function (error) {
        listPanel.innerHTML =
          '<p class="explore-list-empty">Error loading explorations</p>';
      });
  }

  function renderExplorationsList(panel, explorations) {
    if (explorations.length === 0) {
      panel.innerHTML =
        '<h3 class="explore-list-title">Saved Explorations</h3>' +
        '<p class="explore-list-empty">No saved explorations yet.</p>';
      return;
    }

    var html = '<h3 class="explore-list-title">Saved Explorations</h3>';
    explorations.forEach(function (exploration) {
      html += '<div class="explore-list-item">';
      html +=
        '<div class="explore-list-item-title">' +
        escapeHtml(exploration.title) +
        "</div>";
      if (exploration.description) {
        html +=
          '<div class="explore-list-item-desc">' +
          escapeHtml(exploration.description) +
          "</div>";
      }
      html += '<div class="explore-list-item-meta">';
      html += exploration.is_public ? "Public" : "Private";
      html += "</div>";
      html += '<div class="explore-list-item-actions">';
      html +=
        '<button class="explore-action-button" onclick="PhilstubsExplorer.loadSaved(\'' +
        escapeAttr(exploration.id) +
        "')\">Load</button>";
      html +=
        '<button class="explore-action-button explore-action-secondary" onclick="PhilstubsExplorer.shareExploration(\'' +
        escapeAttr(exploration.id) +
        "')\">Share</button>";
      html +=
        '<button class="explore-action-button explore-action-danger" onclick="PhilstubsExplorer.deleteSaved(\'' +
        escapeAttr(exploration.id) +
        "')\">Delete</button>";
      html += "</div></div>";
    });
    panel.innerHTML = html;
  }

  function loadSavedExploration(explorationId) {
    showNotification("Loading exploration...");
    loadExploration(explorationId)
      .then(function (exploration) {
        deserializeGraphState(exploration.graph_state);
        showNotification("Loaded: " + exploration.title);
        // Update URL without reload
        var newUrl =
          window.location.pathname + "?state=" + encodeURIComponent(explorationId);
        window.history.replaceState(null, "", newUrl);
        // Close list panel
        var listPanel = document.getElementById("explore-list-panel");
        if (listPanel) listPanel.classList.remove("explore-list-panel-visible");
      })
      .catch(function (error) {
        showNotification("Load error: " + error.message);
      });
  }

  function shareExploration(explorationId) {
    var shareUrl =
      window.location.origin + "/explore?state=" + encodeURIComponent(explorationId);
    if (navigator.clipboard) {
      navigator.clipboard.writeText(shareUrl).then(function () {
        showNotification("Link copied to clipboard");
      });
    } else {
      showNotification("Share URL: " + shareUrl);
    }
  }

  function deleteSavedExploration(explorationId) {
    if (!confirm("Delete this exploration?")) return;

    showNotification("Deleting...");
    deleteExploration(explorationId)
      .then(function () {
        showNotification("Exploration deleted");
        // Refresh the list
        onLoadClick();
        // Re-open it
        setTimeout(onLoadClick, 100);
      })
      .catch(function (error) {
        showNotification("Delete error: " + error.message);
      });
  }

  // --- Empty State ---

  function showEmptyState() {
    var container = document.getElementById("explore-graph");
    var emptyDiv = document.createElement("div");
    emptyDiv.className = "explore-empty-state";
    emptyDiv.id = "explore-empty-state";
    emptyDiv.innerHTML =
      "<p>Search for legislation or load a topic cluster to begin exploring the legislative graph.</p>" +
      '<p style="font-size: 0.85rem;">Try searching for a bill name, or enter a topic slug like "healthcare" in the cluster panel.</p>';
    container.appendChild(emptyDiv);
  }

  function hideEmptyState() {
    var emptyEl = document.getElementById("explore-empty-state");
    if (emptyEl) emptyEl.remove();
  }

  // --- Event Binding ---

  function bindControlEvents() {
    var searchButton = document.getElementById("explore-search-button");
    if (searchButton) {
      searchButton.addEventListener("click", onSearchSubmit);
    }

    var searchInput = document.getElementById("explore-search-input");
    if (searchInput) {
      searchInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") onSearchSubmit();
      });
    }

    var edgeTypes = [
      "references",
      "amends",
      "supersedes",
      "implements",
      "delegates",
      "similar_to",
    ];
    edgeTypes.forEach(function (edgeType) {
      var checkbox = document.getElementById(
        "explore-edge-filter-" + edgeType
      );
      if (checkbox) {
        checkbox.addEventListener("change", function () {
          onEdgeFilterChange(edgeType, checkbox.checked);
        });
      }
    });

    var depthSelect = document.getElementById("explore-depth-select");
    if (depthSelect) {
      depthSelect.addEventListener("change", function (event) {
        graphState.depth = parseInt(event.target.value, 10) || 1;
      });
    }

    var pathButton = document.getElementById("explore-path-button");
    if (pathButton) {
      pathButton.addEventListener("click", onFindPath);
    }

    var clusterButton = document.getElementById("explore-cluster-button");
    if (clusterButton) {
      clusterButton.addEventListener("click", onLoadCluster);
    }

    var zoomInBtn = document.getElementById("explore-zoom-in");
    if (zoomInBtn) zoomInBtn.addEventListener("click", zoomIn);

    var zoomOutBtn = document.getElementById("explore-zoom-out");
    if (zoomOutBtn) zoomOutBtn.addEventListener("click", zoomOut);

    var zoomResetBtn = document.getElementById("explore-zoom-reset");
    if (zoomResetBtn) zoomResetBtn.addEventListener("click", zoomReset);

    // Save/load buttons
    var saveButton = document.getElementById("explore-save-button");
    if (saveButton) saveButton.addEventListener("click", onSaveClick);

    var loadButton = document.getElementById("explore-load-button");
    if (loadButton) loadButton.addEventListener("click", onLoadClick);

    var saveConfirmBtn = document.getElementById("explore-save-confirm");
    if (saveConfirmBtn) saveConfirmBtn.addEventListener("click", onSaveConfirm);

    var saveCancelBtn = document.getElementById("explore-save-cancel");
    if (saveCancelBtn) saveCancelBtn.addEventListener("click", onSaveCancel);

    // Click on SVG background to deselect
    svg.on("click", function () {
      graphState.selectedNodeId = null;
      nodeGroup
        .selectAll("circle")
        .classed("explore-node-selected", false);
      hideDetailPanel();
    });
  }

  // --- Initialization ---

  function init(options) {
    initializeSvg();
    initializeSimulation();
    bindControlEvents();

    if (options && options.initialNodeId) {
      loadNodeAndCenter(options.initialNodeId);
    } else if (options && options.initialExplorationId) {
      loadSavedExploration(options.initialExplorationId);
    } else {
      showEmptyState();
    }
  }

  // Public API
  window.PhilstubsExplorer = {
    init: init,
    expand: expandNode,
    loadNode: loadNodeAndCenter,
    loadSaved: loadSavedExploration,
    shareExploration: shareExploration,
    deleteSaved: deleteSavedExploration,
  };
})();
