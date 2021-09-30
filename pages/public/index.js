/** @typedef {{load: (Promise<unknown>); flags: (unknown)}} ElmPagesInit */


const template = Object.assign(document.createElement('template'), {
  innerHTML: `
      <style>
        .text {
          white-space: nowrap;
          text-overflow: ellipsis;
          overflow: hidden;
          display: block;
        }

        .text--overflown {
          cursor: pointer;
        }

        .tooltip {
          outline: 0;
          position: absolute;
          top: calc(100% + 8px);
          display: block;
          z-index: 1;
          background: rgba(228, 228, 228);
          border-radius: 8px;
          width: 100%;
          box-sizing: content-box;
          left: -12px;
          opacity: 0;
          width: 0;
          clip: rect(0, 0, 0, 0);
          word-break: break-all;
        }

        .tooltip::before {
          content: '';
          height: 0;
          width: 0;
          border: 8px solid transparent;
          border-bottom-color: rgba(228, 228, 228);
          position: absolute;
          top: -16px;
          right: 16px;
        }

        .tooltip::after {
          content: '';
          height: 8px;
          width: 100%;
          position: absolute;
          top: -8px;
          right: 0;
          background: transparent;
        }

        .tooltip:focus,
        .text--overflown:focus + .tooltip,
        .text--overflown:hover + .tooltip {
          opacity: 1;
          width: 100%;
          padding: 8px 16px;
          clip: auto;
        }
      </style>
      <span class="text"></span>
    `,
});

const runDelayed = window.requestIdleCallback || window.requestAnimationFrame;

const TEXT_ATTRIBUTE = 'text';

class EllipsizableText extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this.shadowRoot.appendChild(template.content.cloneNode(true));
  }

  static get observedAttributes() { return [TEXT_ATTRIBUTE]; }

  connectedCallback() {
    const textContent = this.getAttribute(TEXT_ATTRIBUTE);
    this.textNode = this.shadowRoot.querySelector('.text');

    this.textNode.textContent = textContent;

    runDelayed(this.updateTooltip.bind(this));
  }

  updateTooltip() {
    const isOverflowing = this.textNode.offsetWidth < this.textNode.scrollWidth;
    const existingTooltip = this.getExistingTooltip();

    if (existingTooltip && !isOverflowing) {
      this.shadowRoot.removeChild(existingTooltip);
      this.textNode.removeAttribute('tabIndex');
      this.textNode.classList.remove('text--overflown');
    }

    if (!existingTooltip && isOverflowing) {
      this.textNode.setAttribute('tabIndex', 0);
      this.textNode.classList.add('text--overflown');

      const tooltip = this.textNode.cloneNode(true);

      tooltip.setAttribute('tabIndex', 0);

      tooltip.className = 'tooltip';
      this.shadowRoot.appendChild(tooltip);
    }
  }

  getExistingTooltip() {
    return this.shadowRoot.querySelector('.tooltip');
  }

  attributeChangedCallback(attrName, oldVal, newVal) {
    if (attrName === TEXT_ATTRIBUTE && oldVal !== null) {
      this.textNode.textContent = newVal;
      this.updateTooltip();
    }
  }
}

window.customElements.define('ellipsizable-text', EllipsizableText);

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
