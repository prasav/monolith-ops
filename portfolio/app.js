// ---- Typed terminal ----
const lines = [
  { t: '$ whoami', c: 'p' },
  { t: 'pradeep — full-stack engineer, Mumbai', c: '' },
  { t: '$ uptime && echo $MONTHLY_BILL', c: 'p' },
  { t: '14:32 up 45 days · load 0.30 · $0.00', c: '' },
  { t: '$ cat client-result.txt', c: 'p' },
  { t: 'lead-intake: 6h/wk -> 20min/wk · infra $0/mo', c: '' },
];
const el = document.getElementById('typed');
if (el) {
  let li = 0, ci = 0, out = '';
  const rendered = () => {
    el.innerHTML = out
      + lines.slice(0, li).map(l => `<span class="${l.c}">${l.t}</span>`).join('\n')
      + (li < lines.length ? `\n<span class="${lines[li].c}">${lines[li].t.slice(0, ci)}</span>` : '');
  };
  const tick = () => {
    if (li >= lines.length) return;
    ci++;
    if (ci > lines[li].t.length) {
      out += `<span class="${lines[li].c}">${lines[li].t}</span>\n`;
      li++; ci = 0;
      setTimeout(tick, lines[li - 1].c === 'p' ? 500 : 250);
    } else {
      rendered();
      setTimeout(tick, 28 + Math.random() * 40);
    }
  };
  const io = new IntersectionObserver((es, o) => {
    if (es[0].isIntersecting) { o.disconnect(); tick(); }
  }, { threshold: 0.3 });
  io.observe(el);
}

// ---- Scroll reveal ----
const rio = new IntersectionObserver((es) => {
  es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); rio.unobserve(e.target); } });
}, { threshold: 0.12 });
document.querySelectorAll('.reveal').forEach(n => rio.observe(n));

// ---- Services accordion ----
document.querySelectorAll('.svc-head').forEach(btn => {
  btn.addEventListener('click', () => {
    const item = btn.parentElement;
    const body = item.querySelector('.svc-body');
    const open = item.classList.toggle('open');
    btn.setAttribute('aria-expanded', open);
    body.style.maxHeight = open ? body.scrollHeight + 'px' : '0';
  });
});

// ---- Mumbai clock ----
const fmt = new Intl.DateTimeFormat('en-IN', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Kolkata', hour12: false });
const stamp = () => {
  const s = fmt.format(new Date()) + ' IST';
  const a = document.getElementById('ist-clock'), b = document.getElementById('ist-foot');
  if (a) a.textContent = s;
  if (b) b.textContent = s;
};
stamp(); setInterval(stamp, 20000);

// ---- First service starts open ----
document.querySelectorAll('.svc.open .svc-body').forEach(b => { b.style.maxHeight = b.scrollHeight + 'px'; });
