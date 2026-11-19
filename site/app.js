// wave wallpaper on every canvas.wave: three drifting sine bands from the app icon.
(() => {
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  // base height, amplitude, wavelength, drift, alpha
  const bands = [[0.6, 0.04, 1.2, 0.06, 0.55], [0.7, 0.045, 0.9, -0.045, 0.7], [0.8, 0.035, 0.7, 0.03, 0.85]];
  const tints = ["43,111,138", "79,147,171", "140,195,211"];
  const slots = [];

  function paint(s) {
    const { canvas: c, ctx } = s;
    const w = c.width;
    const h = c.height;
    const sky = ctx.createLinearGradient(0, 0, 0, h);
    sky.addColorStop(0, "#0c1a33");
    sky.addColorStop(1, "#0f6b8c");
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, w, h);
    bands.forEach(([base, amp, len, spd, alpha], i) => {
      ctx.beginPath();
      ctx.moveTo(0, h);
      for (let x = 0; x <= w; x += 6) {
        const p = (x / w) * Math.PI * 2 * len;
        ctx.lineTo(x, (base + amp * Math.sin(p + s.t * spd) + amp * 0.35 * Math.sin(p * 2.3 - s.t * spd * 1.7)) * h);
      }
      ctx.lineTo(w, h);
      ctx.fillStyle = `rgba(${tints[i]},${alpha})`;
      ctx.fill();
    });
  }
  function size(s) {
    const r = s.canvas.getBoundingClientRect();
    const dpr = Math.min(devicePixelRatio || 1, 2);
    s.canvas.width = Math.max(1, Math.round(r.width * dpr));
    s.canvas.height = Math.max(1, Math.round(r.height * dpr));
    paint(s);
  }
  function frame(s, now) {
    s.t += Math.min((now - s.last) / 1000, 0.1);
    s.last = now;
    paint(s);
    s.raf = s.visible && !document.hidden ? requestAnimationFrame((n) => frame(s, n)) : 0;
  }
  function start(s) {
    if (still || s.raf || !s.visible || document.hidden) return;
    s.last = performance.now();
    s.raf = requestAnimationFrame((n) => frame(s, n));
  }

  const io = new IntersectionObserver((entries) => entries.forEach((e) => {
    const s = slots.find((x) => x.canvas === e.target);
    s.visible = e.isIntersecting;
    start(s);
  }));
  document.querySelectorAll("canvas.wave").forEach((canvas) => {
    // data-shift offsets the phase so a second display shows a different frame
    const s = { canvas, ctx: canvas.getContext("2d"), t: Number(canvas.dataset.shift || 0) * 10, last: 0, raf: 0, visible: false };
    slots.push(s);
    size(s);
    io.observe(canvas);
  });
  document.addEventListener("visibilitychange", () => slots.forEach(start));
  addEventListener("resize", () => slots.forEach(size));

  // hero video: started from script (no autoplay attribute) so reduced motion keeps the poster,
  // and paused while off screen or in a hidden tab, the way driftwall itself behaves
  const hero = document.querySelector(".hero-video");
  if (hero && !still) {
    let onScreen = false;
    const sync = () => (onScreen && !document.hidden ? hero.play().catch(() => {}) : hero.pause());
    new IntersectionObserver(([e]) => { onScreen = e.isIntersecting; sync(); }).observe(hero);
    document.addEventListener("visibilitychange", sync);
  }

  document.querySelectorAll(".copy").forEach((b) => b.addEventListener("click", async () => {
    const code = b.parentElement.querySelector("code");
    try {
      await navigator.clipboard.writeText(code.textContent.trim());
      b.textContent = "Copied";
    } catch {
      getSelection().selectAllChildren(code);
      b.textContent = "Selected";
    }
    setTimeout(() => { b.textContent = "Copy"; }, 1600);
  }));
})();
