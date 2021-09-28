/** @typedef {{load: (Promise<unknown>); flags: (unknown)}} ElmPagesInit */

var storageKey = "store";

/** @type ElmPagesInit */
export default {
  load: async function (elmLoaded) {
    const app = await elmLoaded;

    var urlParams = new URLSearchParams(window.location.search);
    var auth_token = urlParams.get('auth_token');
    if (auth_token) {
      localStorage.setItem(storageKey, JSON.stringify({ 'user': { 'authentication_token': auth_token } }));
    }

    app.ports.storeCache.subscribe(function (val) {
      if (val === null) {
        localStorage.removeItem(storageKey);
      } else {
        localStorage.setItem(storageKey, JSON.stringify(val));
      }

      // Report that the new session was stored successfully.
      setTimeout(function () { app.ports.onStoreChange.send(val); }, 0);
    });

    // Whenever localStorage changes in another tab, report it if necessary.
    window.addEventListener("storage", function (event) {
      if (event.storageArea === localStorage && event.key === storageKey) {
        app.ports.onStoreChange.send(event.newValue);
      }
    }, false);
  },
  flags: function () {
    var dimensions = { 'width': window.innerWidth, 'height': window.innerHeight };

    return {
      'window': dimensions,
      'viewer': localStorage.getItem(storageKey)
    };
  },
};
