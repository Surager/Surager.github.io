(function () {
  var attempts = 0;
  var maxAttempts = 20;

  function initSearch() {
    var input = document.getElementById("sidebar-search-input");
    var results = document.getElementById("sidebar-search-results-container");

    if (!input || !results) {
      return;
    }

    if (!window.SimpleJekyllSearch) {
      attempts += 1;
      if (attempts < maxAttempts) {
        window.setTimeout(initSearch, 50);
      }
      return;
    }

    window.SimpleJekyllSearch({
      json: input.dataset.searchJson || "/assets/simple-jekyll-search/search.json",
      searchInput: input,
      resultsContainer: results,
      searchResultTemplate: '<li><a href="{url}">{title}</a></li>',
      limit: 999,
      fuzzy: true
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initSearch);
  } else {
    initSearch();
  }
})();
