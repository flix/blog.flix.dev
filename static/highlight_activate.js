// Zola records the fence language in `data-lang`, but highlight.js reads a
// `language-*` class. Without one it falls back to auto-detection, and since
// this bundle only carries the Flix grammar, every block -- Scala, shell,
// plain text -- comes out highlighted as Flix. Tag each block explicitly and
// opt the rest out.
document.querySelectorAll('pre code').forEach((block) => {
    const lang = block.dataset.lang;
    block.classList.add(lang && hljs.getLanguage(lang) ? `language-${lang}` : 'nohighlight');
});

hljs.highlightAll();
