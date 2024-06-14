# wrong-use-of-git database
wugdb is a Nushell module providing a tool for storing and retrieving structured Nushell data in a Git branch. 

The data is stored in JSON files in a dedicated, unrelated (orphan) branch. A Git commit is generated each time the stored data is updated.

The commands provided are `wugdb list`, `wugdb get`, `wugdb store`, and `wugdb drop`.  Each supports `--help` for more detail. 

More details about the internals of wugdb are available [in a blog post](http://dee.underscore.world/blog/git-as-a-database-kind-of/)

This module works, but has minimal to no error handling, and is more of a proof of concept. Use in production is generally not recommended (unless you really want to).

The plural of wugdb is wugdbs. 

## Example
```shellsession
> use wugdb
> git init
> [ 1 2 3 ] | wugdb store first
> [ 4 5 6 ] | wugdb store second
> wugdb get first 
╭───┬───╮
│ 0 │ 1 │
│ 1 │ 2 │
│ 2 │ 3 │
╰───┴───╯
> wugdb get second | append [ 7 8 9 ] | wugdb store second
> wugdb get second
╭───┬───╮
│ 0 │ 4 │
│ 1 │ 5 │
│ 2 │ 6 │
│ 3 │ 7 │
│ 4 │ 8 │
│ 5 │ 9 │
╰───┴───╯
```

## License
wugdb is available under the MIT license. See [LICENSE](./LICENSE) for details.

## Repositories
This project can be found at:
* https://github.com/DeeUnderscore/wugdb
* https://git.underscore.world/d/wugdb 
