// Small progressive enhancements; the site works without JavaScript.
(function () {
  "use strict";

  // Copy buttons on code blocks. When a block shows an interactive session
  // (lines like `root@host:~# cmd` or `$ cmd`), copy only the commands,
  // without prompts or output.
  var PROMPT = /^(?:[\w.-]+@[\w.-]+(?::[^\s#$]*)?[#$]|\$)\s+/;

  function commandsOnly(text) {
    var lines = text.replace(/\n$/, "").split("\n");
    var cmds = lines.filter(function (l) { return PROMPT.test(l); });
    if (cmds.length === 0) return text;
    return cmds.map(function (l) { return l.replace(PROMPT, ""); }).join("\n") + "\n";
  }

  function copy(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); } finally { document.body.removeChild(ta); }
    return Promise.resolve();
  }

  document.querySelectorAll(".highlight > pre").forEach(function (pre) {
    var host = pre.parentElement;
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "copy-code";
    btn.textContent = "Copy";
    btn.setAttribute("aria-label", "Copy code to clipboard");
    btn.addEventListener("click", function () {
      var code = pre.querySelector("code") || pre;
      copy(commandsOnly(code.innerText)).then(function () {
        btn.textContent = "Copied";
        setTimeout(function () { btn.textContent = "Copy"; }, 1500);
      }, function () {
        btn.textContent = "Failed";
      });
    });
    host.classList.add("has-copy");
    host.appendChild(btn);
  });

  // Anchor links on post headings (kramdown generates the ids).
  document.querySelectorAll(".post-content h2[id], .post-content h3[id]").forEach(function (h) {
    var a = document.createElement("a");
    a.className = "heading-anchor";
    a.href = "#" + h.id;
    a.setAttribute("aria-label", "Link to this section");
    a.textContent = "#";
    h.appendChild(a);
  });
})();
