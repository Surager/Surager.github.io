(function () {
  function initReveal() {
    if (!window.Reveal || !window.RevealMarkdown || !window.RevealMath || !window.RevealHighlight) {
      window.setTimeout(initReveal, 50);
      return;
    }

    var wraps = document.getElementsByClassName("wrap");

    for (var i = 0; i < wraps.length; i += 1) {
      wraps[i].classList.add("reveal");
    }

    window.Reveal.initialize({
      height: "100%",
      hash: true,
      mouseWheel: true,
      navigationMode: "linear",
      plugins: [window.RevealMarkdown, window.RevealMath, window.RevealHighlight]
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initReveal);
  } else {
    initReveal();
  }
})();
