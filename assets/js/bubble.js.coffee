diameter = 960
format = d3.format(",d")
color = d3.scale.category20c()

bubble = d3.layout.pack()
  .sort(null)
  .size([diameter, diameter])
  .padding(1.5)

svg = d3.select("body").append("svg")
  .attr("width", diameter)
  .attr("height", diameter)
  .attr("class", "bubble")

d3.json "contacts.json?limit=200", (error, root) ->
  data = {children: root}
  node = svg.selectAll(".node")
    .data(bubble.nodes(data).filter((d) -> !d.children))
    .enter().append("g")
    .attr("class", "node")
    .attr("transform", (d) -> "translate(#{d.x},#{d.y})")

  node.append("title")
    .text((d) -> "#{d.className}: #{d.value}")

  node.append("circle")
    .attr("r", (d) -> d.r)
    .style("fill", (d) -> color(d.name))

  node.append("text")
    .attr("dy", ".3em")
    .style("text-anchor", "middle")
    .text((d) -> d.name.substring(0, d.r / 3))

d3.select(self.frameElement).style("height", "#{diameter}px")
