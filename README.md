# banerjerishi.com

## Acknowledgments

This website is a fork of [filiph/filiphnet](https://github.com/filiph/filiphnet), originally created by **Filip Hracek**, whose work I’ve long admired. His minimal, Markdown-first approach to personal publishing inspired me to build upon it with my own customizations and additions.

Check out the original project [here](https://github.com/filiph/filiphnet).

Code for Rishi's personal homepage.

Use `make` to build and deploy this. For example:

```
$ make serve
```

This will build the project and will serve it on localhost.

To deploy:

```
$ make deploy
```

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
