"use strict";

const PLAYGROUND_URL = "https://luk3yx.gitlab.io/minetest-flow-playground/";

function getPlaygroundLink(code) {
    return PLAYGROUND_URL + "#code=" + encodeURIComponent(code);
}

function addPlaygroundBtn(el, code) {
    const btn = document.createElement("button");
    btn.onclick = () => {
        window.open(getPlaygroundLink(code));
    };
    btn.textContent = "\u25b6";
    btn.title = "Run this code online";
    btn.style.float = "right";

    el.insertBefore(btn, el.firstChild);
}

const TEMPLATE = `
local gui = flow.widgets

local form = flow.make_gui(function(player, ctx)
%
end)

form:show(core.get_player_by_name("playground"))
`.trim();

function addPlayBtn({el, result, text}) {
    if (!el.classList.contains("language-lua"))
        return;

    // The playground does not support styling
    if (text.indexOf("style = {") > 0 || text.indexOf("gui.Style") > 0)
        return;

    if (text.startsWith("gui.") && text.trim().endsWith("}")) {
        addPlaygroundBtn(el, TEMPLATE.replace("%",
            "    return " + text.trim().replaceAll("\n", "\n    ")));
    } else if (/^local (my_gui|form) = flow.make_gui\(function\(player, ctx\)\n/.test(text) &&
            text.trim().endsWith("\nend)")) {
        addPlaygroundBtn(el, TEMPLATE.replace("%",
            text.trim().split("\n").slice(1, -1).join("\n")));
    }
}

hljs.addPlugin({
    'after:highlightElement': addPlayBtn,
})
