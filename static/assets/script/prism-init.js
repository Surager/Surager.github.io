(function () {
  function initPrism() {
    if (!window.Prism || !window.Prism.plugins || !window.Prism.plugins.toolbar) {
      window.setTimeout(initPrism, 50);
      return;
    }

    var contentBlocks = document.getElementsByClassName("content");

    for (var i = 0; i < contentBlocks.length; i += 1) {
      contentBlocks[i].classList.add("line-numbers", "match-braces");
    }

    window.Prism.plugins.toolbar.registerButton("select-code", function (env) {
      var button = document.createElement("button");
      button.textContent = "select this " + env.language;
      button.addEventListener("click", function () {
        if (document.body.createTextRange) {
          var textRange = document.body.createTextRange();
          textRange.moveToElementText(env.element);
          textRange.select();
        } else if (window.getSelection) {
          var selection = window.getSelection();
          var range = document.createRange();
          range.selectNodeContents(env.element);
          selection.removeAllRanges();
          selection.addRange(range);
        }
      });
      return button;
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPrism);
  } else {
    initPrism();
  }
})();
