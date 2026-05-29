// Sherpa docs — custom enhancements layered on top of the mkdocs-shadcn theme.
// Restores image zoom (glightbox) and the "Was this page helpful?" feedback widget.

(function () {
  "use strict";

  function gaEvent(action, label) {
    if (typeof window.gtag === "function") {
      window.gtag("event", action, {
        event_category: "feedback",
        event_label: label,
      });
    }
  }

  function isHomeLightLocked() {
    return document.documentElement.dataset.sherpaLightLocked === "true" || !!document.querySelector(".sherpa-home");
  }

  function forceHomeLightTheme() {
    if (!isHomeLightLocked()) return;

    var root = document.documentElement;
    root.classList.remove("dark");
    root.classList.add("sherpa-home-page");
    root.dataset.sherpaLightLocked = "true";
    root.style.colorScheme = "light";

    if (typeof updatePygmentsStylesheet === "function") {
      updatePygmentsStylesheet();
    }
  }

  function lockHomeLightTheme() {
    if (!isHomeLightLocked()) return;

    forceHomeLightTheme();

    document.addEventListener("click", function (event) {
      var target = event.target && event.target.nodeType === Node.ELEMENT_NODE
        ? event.target
        : event.target && event.target.parentElement;
      var toggle = target ? target.closest("[data-sherpa-theme-toggle], button[onclick*='onThemeSwitch']") : null;
      if (!toggle) return;

      event.preventDefault();
      event.stopImmediatePropagation();
      forceHomeLightTheme();
    }, true);

    new MutationObserver(forceHomeLightTheme).observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });
  }

  // ── Image zoom (glightbox) ────────────────────────────────
  function initLightbox() {
    if (typeof GLightbox === "undefined") return;
    var content = document.querySelector("article .typography");
    if (!content) return;

    content.querySelectorAll("img").forEach(function (img) {
      // Skip inline iconify SVGs / tiny decorative images.
      if (img.closest("a")) return;
      if (img.classList.contains("iconify")) return;
      var link = document.createElement("a");
      link.href = img.getAttribute("src");
      link.className = "glightbox";
      link.setAttribute("data-type", "image");
      img.parentNode.insertBefore(link, img);
      link.appendChild(img);
    });

    GLightbox({ selector: ".glightbox", touchNavigation: true, loop: false });
  }

  // ── Feedback widget ───────────────────────────────────────
  function initFeedback() {
    var content = document.querySelector("article .typography");
    if (!content || content.querySelector(".sherpa-home") || document.getElementById("page-feedback")) return;

    var wrap = document.createElement("div");
    wrap.id = "page-feedback";
    wrap.className = "page-feedback";
    wrap.innerHTML =
      '<span class="page-feedback__title">Was this page helpful?</span>' +
      '<div class="page-feedback__buttons">' +
      '<button type="button" data-value="1" aria-label="This page was helpful">👍</button>' +
      '<button type="button" data-value="0" aria-label="This page could be improved">👎</button>' +
      "</div>";

    content.appendChild(wrap);

    wrap.querySelectorAll("button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var helpful = btn.getAttribute("data-value") === "1";
        gaEvent(helpful ? "helpful" : "not_helpful", location.pathname);
        wrap.querySelector(".page-feedback__title").textContent = helpful
          ? "Thanks for your feedback!"
          : "Thanks — help us improve by opening an issue.";
        wrap.querySelector(".page-feedback__buttons").remove();
      });
    });
  }

  // ── Accessibility: hide decorative Material Icons from screen readers ──
  // The icon ligatures (e.g. "track_changes") would otherwise be read aloud.
  function hideDecorativeIcons() {
    document.querySelectorAll(".material-icons").forEach(function (el) {
      if (!el.hasAttribute("aria-hidden")) el.setAttribute("aria-hidden", "true");
    });
  }

  function keepStargazerFallback() {
    var stargazers = Array.prototype.slice.call(document.querySelectorAll("#stargazers, [data-github-stars]"));
    if (!stargazers.length) return;

    function restore(target) {
      var fallback = target.getAttribute("data-fallback") || "21";
      var value = target.textContent.trim();
      if (!/^[\d,]+$/.test(value)) target.textContent = fallback;
    }

    function setStars(value) {
      stargazers.forEach(function (target) {
        target.textContent = value;
      });
    }

    function repoPathFromTarget(target) {
      var repo = target.getAttribute("data-github-stars");
      if (repo && repo !== "true") return repo.replace(/^\/+|\/+$/g, "");

      var link = target.closest("a[href*='github.com']");
      if (!link) return null;

      try {
        var url = new URL(link.href);
        return url.pathname.replace(/^\/+|\/+$/g, "").split("/").slice(0, 2).join("/");
      } catch (error) {
        return null;
      }
    }

    stargazers.forEach(function (target) {
      restore(target);
      new MutationObserver(function () { restore(target); }).observe(target, {
        childList: true,
        characterData: true,
        subtree: true,
      });
    });

    var repoPath = repoPathFromTarget(stargazers[0]);
    if (!repoPath || typeof fetch !== "function") return;

    fetch("https://api.github.com/repos/" + repoPath, {
      headers: { Accept: "application/vnd.github+json" },
    })
      .then(function (response) {
        if (!response.ok) throw new Error("GitHub stars unavailable");
        return response.json();
      })
      .then(function (data) {
        if (typeof data.stargazers_count === "number") {
          setStars(data.stargazers_count.toLocaleString());
        }
      })
      .catch(function () {});
  }

  function initHomeAnchors() {
    var home = document.querySelector(".sherpa-home");
    if (!home || document.documentElement.dataset.sherpaHomeAnchorsReady === "true") return;

    document.documentElement.dataset.sherpaHomeAnchorsReady = "true";
    function registerScrollPlugin() {
      if (!window.gsap || !window.ScrollToPlugin) return false;

      window.gsap.registerPlugin(window.ScrollToPlugin);
      return true;
    }

    registerScrollPlugin();

    document.addEventListener("click", function (event) {
      var eventTarget = event.target && event.target.nodeType === Node.ELEMENT_NODE
        ? event.target
        : event.target && event.target.parentElement;
      var anchor = eventTarget ? eventTarget.closest("[data-sherpa-scroll]") : null;
      if (!anchor) return;

      var selector = anchor.getAttribute("data-sherpa-scroll");
      var target = selector && selector !== "top" ? document.querySelector(selector) : null;
      if (!target && selector !== "top") return;

      var offset = 0;
      var top = target
        ? target.getBoundingClientRect().top + window.scrollY - offset
        : 0;

      event.preventDefault();
      event.stopPropagation();
      if (registerScrollPlugin()) {
        window.gsap.to(window, {
          duration: 1,
          ease: "power3.inOut",
          scrollTo: { y: Math.max(0, top), autoKill: false },
          onComplete: function () {
            if (selector && selector !== "top") history.replaceState(null, "", selector);
          },
        });
      } else {
        window.scrollTo({ top: Math.max(0, top), behavior: "smooth" });
        if (selector && selector !== "top") history.replaceState(null, "", selector);
      }
    }, true);
  }

  // ── Homepage hero frame-sequence scrollytelling ─────────
  function initHomeHero() {
    var hero = document.querySelector(".sherpa-hero-scroll");
    var canvas = document.querySelector(".sherpa-hero-canvas");
    var loader = document.querySelector(".sherpa-hero-loader");
    var loaderPercent = loader ? loader.querySelector(".sherpa-hero-loader__percent") : null;
    if (!hero || !canvas || canvas.dataset.sherpaHeroReady === "true") return;

    canvas.dataset.sherpaHeroReady = "true";

    var SEQUENCE_FRAME_COUNT = Number(hero.getAttribute("data-sherpa-frame-count")) || 180;
    var FRAME_PATH = hero.getAttribute("data-sherpa-frame-path") || "images/herosection/ezgif-frame-{index}.jpg";
    var START_FRAME_PATH = hero.getAttribute("data-sherpa-start-frame") || "images/startframe.png";
    var END_FRAME_PATH = hero.getAttribute("data-sherpa-end-frame") || "images/endframe.png";
    var MAX_DPR = 2;
    var frameUrls = buildFrameUrls();
    var totalFrames = frameUrls.length;
    var frames = new Array(totalFrames);
    var context = canvas.getContext("2d", { alpha: false });
    var rafId = null;
    var snapRafId = null;
    var scrollBehaviorSnapshot = null;
    var targetFrame = 0;
    var isAutoScrolling = false;
    var touchStartY = null;
    var loadedFrames = 0;
    var completedFrames = 0;
    var ready = false;
    var hasDrawn = false;
    function clamp(value, min, max) {
      return Math.min(Math.max(value, min), max);
    }

    function buildFrameUrls() {
      var urls = [START_FRAME_PATH];
      for (var index = 0; index < SEQUENCE_FRAME_COUNT; index += 1) {
        urls.push(FRAME_PATH.replace("{index}", String(index + 1).padStart(3, "0")));
      }
      urls.push(END_FRAME_PATH);
      return urls;
    }

    function frameUrl(index) {
      return frameUrls[index];
    }

    function resizeCanvas() {
      var ratio = Math.min(window.devicePixelRatio || 1, MAX_DPR);
      canvas.width = Math.ceil(window.innerWidth * ratio);
      canvas.height = Math.ceil(window.innerHeight * ratio);
      if (context) {
        context.imageSmoothingEnabled = true;
        context.imageSmoothingQuality = "high";
      }
      schedule();
    }

    function nearestLoadedFrame(index) {
      if (frames[index]) return frames[index];

      for (var offset = 1; offset < totalFrames; offset += 1) {
        var lower = index - offset;
        var upper = index + offset;
        if (lower >= 0 && frames[lower]) return frames[lower];
        if (upper < totalFrames && frames[upper]) return frames[upper];
      }
      return null;
    }

    function drawFrame(index) {
      if (!context || !canvas.width || !canvas.height) return;

      var image = nearestLoadedFrame(index);
      if (!image) return;

      var canvasAspect = canvas.width / canvas.height;
      var imageAspect = image.naturalWidth / image.naturalHeight;
      var drawWidth;
      var drawHeight;

      if (imageAspect > canvasAspect) {
        drawHeight = canvas.height;
        drawWidth = drawHeight * imageAspect;
      } else {
        drawWidth = canvas.width;
        drawHeight = drawWidth / imageAspect;
      }

      var x = (canvas.width - drawWidth) / 2;
      var y = (canvas.height - drawHeight) / 2;

      context.fillStyle = "#000";
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.drawImage(image, x, y, drawWidth, drawHeight);
      canvas.dataset.sherpaFrame = String(index + 1);
      hasDrawn = true;
    }

    function tick() {
      rafId = null;
      if (ready || loadedFrames > 0) drawFrame(targetFrame);
    }

    function schedule() {
      if (rafId === null) rafId = window.requestAnimationFrame(tick);
    }

    function updateActiveState() {
      var rect = hero.getBoundingClientRect();
      var active = rect.bottom > 0 && rect.top < window.innerHeight;
      document.body.classList.toggle("sherpa-hero-active", active);
    }

    function heroGeometry() {
      var top = hero.getBoundingClientRect().top + window.scrollY;
      var maxScroll = Math.max(1, hero.offsetHeight - window.innerHeight);
      return {
        top: top,
        end: top + maxScroll,
        maxScroll: maxScroll,
      };
    }

    function frameForScrollFraction(scrollFraction) {
      if (scrollFraction <= 0.001) return 0;
      if (scrollFraction >= 0.999) return totalFrames - 1;

      return clamp(Math.floor(scrollFraction * (totalFrames - 2)) + 1, 1, totalFrames - 2);
    }

    function updateHeroPhase(scrollFraction) {
      var phase = "transition";

      if (!isAutoScrolling && scrollFraction <= 0.001) {
        phase = "start";
      } else if (!isAutoScrolling && scrollFraction >= 0.999) {
        phase = "end";
      }

      hero.setAttribute("data-sherpa-hero-phase", phase);
      hero.style.setProperty("--sherpa-hero-progress", scrollFraction.toFixed(4));
    }

    function updateFromScroll() {
      var geometry = heroGeometry();
      var scrolled = clamp(window.scrollY - geometry.top, 0, geometry.maxScroll);
      var scrollFraction = clamp(scrolled / geometry.maxScroll, 0, 1);
      targetFrame = frameForScrollFraction(scrollFraction);
      updateHeroPhase(scrollFraction);
      updateActiveState();
      schedule();
    }

    function clearHomeHash() {
      if (!location.hash) return;
      history.replaceState(null, "", location.pathname + location.search);
    }

    function lockNativeScrollBehavior() {
      if (scrollBehaviorSnapshot) return;

      scrollBehaviorSnapshot = {
        root: document.documentElement.style.scrollBehavior,
        body: document.body ? document.body.style.scrollBehavior : "",
      };
      document.documentElement.style.scrollBehavior = "auto";
      if (document.body) document.body.style.scrollBehavior = "auto";
    }

    function restoreNativeScrollBehavior() {
      if (!scrollBehaviorSnapshot) return;

      document.documentElement.style.scrollBehavior = scrollBehaviorSnapshot.root;
      if (document.body) document.body.style.scrollBehavior = scrollBehaviorSnapshot.body;
      scrollBehaviorSnapshot = null;
    }

    function snapTo(position) {
      var distance = Math.abs(window.scrollY - position);
      var duration = clamp(distance / Math.max(1, window.innerHeight) * 0.3, 0.78, 1.18);
      var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      var startY = window.scrollY;
      var targetY = Math.max(0, position);
      var deltaY = targetY - startY;
      var startTime = window.performance.now();

      isAutoScrolling = true;
      hero.setAttribute("data-sherpa-hero-phase", "transition");

      if (snapRafId !== null) {
        window.cancelAnimationFrame(snapRafId);
        restoreNativeScrollBehavior();
      }

      lockNativeScrollBehavior();

      function setScroll(top) {
        window.scrollTo(0, top);
      }

      function finishSnap() {
        snapRafId = null;
        setScroll(targetY);
        isAutoScrolling = false;
        updateFromScroll();
        if (targetY <= heroGeometry().top + 1) clearHomeHash();
        restoreNativeScrollBehavior();
      }

      if (reduceMotion || Math.abs(deltaY) < 1) {
        finishSnap();
        return;
      }

      function step(now) {
        var progress = clamp((now - startTime) / (duration * 1000), 0, 1);
        var eased = 1 - Math.pow(1 - progress, 2);
        setScroll(startY + deltaY * eased);
        updateFromScroll();

        if (progress < 1) {
          snapRafId = window.requestAnimationFrame(step);
        } else {
          finishSnap();
        }
      }

      snapRafId = window.requestAnimationFrame(step);
    }

    function snapTargetForDirection(direction) {
      var geometry = heroGeometry();
      var scrollY = window.scrollY;
      var heroRect = hero.getBoundingClientRect();
      var heroVisible = heroRect.bottom > 0 && heroRect.top < window.innerHeight;
      var tolerance = 8;

      if (direction > 0 && heroVisible && scrollY < geometry.end - tolerance) {
        return geometry.end;
      }

      if (direction < 0 && scrollY > geometry.top + tolerance && heroVisible) {
        return geometry.top;
      }

      return null;
    }

    function handleScrollIntent(direction, event) {
      if (!direction) return false;

      var target = snapTargetForDirection(direction);
      if (target === null) return false;

      if (event && event.cancelable) event.preventDefault();
      if (!isAutoScrolling) snapTo(target);
      return true;
    }

    function handleWheel(event) {
      handleScrollIntent(event.deltaY > 0 ? 1 : -1, event);
    }

    function handleTouchStart(event) {
      if (!event.touches || event.touches.length !== 1) return;
      touchStartY = event.touches[0].clientY;
    }

    function handleTouchMove(event) {
      if (touchStartY === null || !event.touches || event.touches.length !== 1) return;

      var delta = touchStartY - event.touches[0].clientY;
      if (Math.abs(delta) < 12) return;
      if (handleScrollIntent(delta > 0 ? 1 : -1, event)) touchStartY = null;
    }

    function handleKeydown(event) {
      var target = event.target;
      if (target && target.closest && target.closest("input, textarea, select, [contenteditable='true']")) return;

      var downKeys = ["ArrowDown", "PageDown", " "];
      var upKeys = ["ArrowUp", "PageUp"];
      var direction = downKeys.indexOf(event.key) !== -1 ? 1 : upKeys.indexOf(event.key) !== -1 ? -1 : 0;
      if (event.key === " " && event.shiftKey) direction = -1;

      handleScrollIntent(direction, event);
    }

    function updateLoader() {
      if (!loaderPercent) return;

      var percent = Math.round((completedFrames / totalFrames) * 100);
      loaderPercent.textContent = String(percent) + "%";
    }

    function finishLoading() {
      ready = true;
      updateFromScroll();
      if (!hasDrawn) drawFrame(targetFrame);
      if (loader) loader.classList.add("is-hidden");
      canvas.dataset.sherpaLoaded = "true";
    }

    function markComplete() {
      completedFrames += 1;
      updateLoader();
      if (completedFrames >= totalFrames) finishLoading();
    }

    function preloadFrames() {
      updateLoader();
      for (var index = 0; index < totalFrames; index += 1) {
        (function (frameIndex) {
          var image = new Image();
          image.decoding = "async";
          image.onload = function () {
            frames[frameIndex] = image;
            loadedFrames += 1;
            if (frameIndex === 0) drawFrame(0);
            markComplete();
          };
          image.onerror = markComplete;
          image.src = frameUrl(frameIndex);
        })(index);
      }
    }

    resizeCanvas();
    updateFromScroll();
    preloadFrames();

    window.addEventListener("scroll", updateFromScroll, { passive: true });
    window.addEventListener("wheel", handleWheel, { passive: false });
    window.addEventListener("touchstart", handleTouchStart, { passive: true });
    window.addEventListener("touchmove", handleTouchMove, { passive: false });
    window.addEventListener("keydown", handleKeydown);
    window.addEventListener("resize", function () {
      resizeCanvas();
      updateFromScroll();
    }, { passive: true });
  }

  function init() {
    lockHomeLightTheme();
    initLightbox();
    initFeedback();
    hideDecorativeIcons();
    keepStargazerFallback();
    initHomeAnchors();
    initHomeHero();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
