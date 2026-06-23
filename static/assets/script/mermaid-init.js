(function () {
  function initMermaidBlocks() {
    if (!window.mermaid) {
      window.setTimeout(initMermaidBlocks, 50);
      return;
    }

    var blocks = document.getElementsByClassName("language-mermaid");

    for (var i = 0; i < blocks.length; i += 1) {
      var block = blocks[i];

      if (block.nodeName !== "CODE") {
        continue;
      }

      var mermaid = document.createElement("div");
      mermaid.classList.add("mermaid");
      mermaid.textContent = block.textContent;
      block.parentNode.insertAdjacentElement("beforebegin", mermaid);
    }

    if (window.mermaid.init) {
      window.mermaid.init(undefined, document.querySelectorAll(".mermaid"));
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initMermaidBlocks);
  } else {
    initMermaidBlocks();
  }
})();
