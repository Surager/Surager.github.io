(function () {
  function setZero(value) {
    return value < 10 ? "0" + value : value;
  }

  function updateRuntime(widget) {
    var birthDay = new Date(widget.dataset.start);
    var now = new Date();
    var elapsed = now.getTime() - birthDay.getTime();
    var days = Math.floor(elapsed / (24 * 60 * 60 * 1000));
    var hours = Math.floor((elapsed / (60 * 60 * 1000)) % 24);
    var minutes = Math.floor((elapsed / (60 * 1000)) % 60);
    var seconds = Math.floor((elapsed / 1000) % 60);

    widget.querySelector("[data-runtime-day]").textContent = days;
    widget.querySelector("[data-runtime-hour]").textContent = setZero(hours);
    widget.querySelector("[data-runtime-minute]").textContent = setZero(minutes);
    widget.querySelector("[data-runtime-second]").textContent = setZero(seconds);
  }

  function initRuntime() {
    var widget = document.querySelector("[data-runtime]");

    if (!widget) {
      return;
    }

    updateRuntime(widget);
    window.setInterval(function () {
      updateRuntime(widget);
    }, 1000);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initRuntime);
  } else {
    initRuntime();
  }
})();
