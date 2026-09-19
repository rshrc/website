# banerjerishi.com

## Acknowledgments

This website is a fork of [filiph/filiphnet](https://github.com/filiph/filiphnet), originally created by **Filip Hracek**, whose work I’ve long admired. His minimal, Markdown-first approach to personal publishing inspired me to build upon it with my own customizations and additions.

Check out the original project [here](https://github.com/filiph/filiphnet).

Code for Rishi's personal homepage.

Use `make` to build and serve this. For example:

```
$ make run
```

This starts a watch server on `http://localhost:3002` and rebuilds on file changes.

To deploy:

```
$ make deploy
```

## Tooling

Everything runs through `make`:

```bash
make run              # build, serve on localhost:3002, rebuild on changes (make r)
make builder          # build into ./build
make deploy           # build and ship to Firebase
make covers           # fetch cover art for new Spotify links
make update-sitemap   # rewrite sitemap.xml from markdowns/ (make u)
make check-sitemap-urls  # every sitemap URL has a built page (make c)
```

Where things live:

- `src/index.md` is the homepage prose. Its lists live in `src/home/*.yaml`,
  placed with `<!-- SECTION name -->`. The essay list is built from the
  published articles.
- `src/css/` and `src/js/` hold the styles and scripts. Templates pull them
  in with `/* INCLUDE css/home.css */`, so every page still ships as a
  single HTML file.
- `tool/` has the generators. Shared Ruby lives in `tool/lib/`.

## Write new articles

Make sure that `htmlgen.toml` points to the right file paths
(Obsidian vault). Then just create a new Obsidian note in that path
that looks something like this:

```markdown
---
description: The description of the article
date: August 2023
created: 2023-08-07T08:00:00.000Z
publish: true
---

Contents of article go here. You can use _the usual_ Markdown plus extensions
you're used to from places like GitHub.

You can also add images, either through normal Markdown tags,
or by dragging them into the Obsidian window as an embed:

![[image.png]]

That's all!
```

# Todos

1. create newsletter for integration
