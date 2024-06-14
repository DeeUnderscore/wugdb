# create a new parentless commit and branch with the data piped in
def commit_new_branch [
  filename: string
  branch: string
] {
  let object = ($in | to json -i 2 | git hash-object --stdin -w)

  let tree = ([
    (make-ls-tree-entry $object $filename)
  ] | to git-ls-tree | git mktree -z)

  let commit = (git commit-tree -m $'Initial commit adding ($filename)' $tree)

  git update-ref -m $"wugdb: create branch with ($filename)"  $"refs/heads/($branch)" $commit 
}

# update an existing branch with a new commit with the data piped in
def update_branch [
  filename: string
  branch: string
] {
  let input = $in 

  let prev_tree = (git ls-tree -z $branch | from git-ls-tree)
  
  let new_object = ($input | to json -i 2 | git hash-object --stdin -w)

  # this is mostly useful to present a relevant commit message 
  let already_present = ($prev_tree | any {|row| $row.path == $filename})

  let new_tree = if $already_present {
    # we drop and readd the relevant entry, because there isn't anything there
    # that needs to be preserved via updating the entry instead 
    $prev_tree |
      where {|it| $it.path != $filename} |
      append (
        make-ls-tree-entry $new_object $filename 
      )
  } else {
    $prev_tree | append (
      make-ls-tree-entry $new_object $filename 
    )
  }

  let new_tree_obj = ($new_tree | to git-ls-tree | git mktree -z)
  let parent = (git rev-parse $branch)
  let message = if $already_present {
    $'Update ($filename)'
  } else {
    $'Add ($filename)'
  }
  let commit = (git commit-tree -m $message -p $parent $new_tree_obj)

  git update-ref -m $"wugdb: update ($filename)" $"refs/heads/($branch)" $commit
}

def drop-file-from-branch [
  filename: string,
  branch: string 
] {
  let prev_tree = (git ls-tree -z $branch | from git-ls-tree)
  if (not ($prev_tree | any {|row| $row.path == $filename})) {
    error make -u {msg: "No such key"}
  }

  let new_tree = ($prev_tree | where {|it| $it.path != $filename})
  let parent = (git rev-parse $branch)
  let message = $"Drop ($filename)"
  let new_tree_obj = ($new_tree | to git-ls-tree | git mktree -z)

  let commit = (git commit-tree -m $message -p $parent $new_tree_obj)

  git update-ref -m $"wugdb: drop ($filename)" $"refs/heads/($branch)" $commit
}

# create a structured ls-tree entry for a file
def make-ls-tree-entry [ 
  hash: string, # the hash of the file
  path: string  # the filename
] {
  {
    "objectmode": "100644",
    "objecttype": "blob",
    "objectname": $hash,
    "path": $path
  }
}

# convert output of `git ls-tree -z` into structured data
def "from git-ls-tree" [] {
  split row "\u{0}" |
  compact --empty |  # chomp the 0-length entry after the last nul byte
  each {|it| $it |
    parse --regex '(?<objectmode>\d+) (?<objecttype>\w+) (?<objectname>[0-9a-f]+)\t(?P<path>[^\x00/]+)'} |
  flatten
}

# convert structured ls-tree data into `git ls-tree -z` like output
def "to git-ls-tree" [] {
  # each entry has to be terminated with a nul byte, rather than having the
  # entries separated with nul bytes, so we can't use `str join "\u{0}"` 
  each {|it| $"($it.objectmode) ($it.objecttype) ($it.objectname)\t($it.path)\u{0}"} | str join
}

# ask git if the given branch exists
def branch-exists [
  branch: string 
] {
  git rev-parse --verify --end-of-options $"($branch)^{commit}" |
    complete | $in.exit_code == 0
}

def get-branch-name [
  target_branch
] {
  if $target_branch != null {
    $target_branch
  } else if "WUGDB_BRANCH" in $env {
    $env.WUGDB_BRANCH
  } else {
    "data"
  }
}

# Retrieve data stored under the given key
export def get [
  key: string,  # key to retrieve
  --branch(-b): string  # branch under which the data is stored 
] {
  let filename = $"($key).json"
  let branch = (get-branch-name $branch)

  git cat-file blob $"($branch):($filename)" | from json
}

# List all keys of the records currently stored
export def list [
  --branch(-b): string # branch to list keys from
] {
  let branch = (get-branch-name $branch)

  git ls-tree -z $branch |
    from git-ls-tree |
    select path |
    where {|it| $it.path | str ends-with '.json'} |
    each {|it| $it.path | str replace '.json' ''}
}

# Replace the data under the given key with the data piped in to this command
export def store [
  key: string,  # key to update
  --branch(-b): string,  # branch under which the data is stored
] {
  let new_data = $in
  let filename = $"($key).json"
  let branch = (get-branch-name $branch)

  if (branch-exists $branch) {
    $new_data | update_branch $filename $branch
  } else {
    $new_data | commit_new_branch $filename $branch
  }
}

# Delete a key and all its data
# 
# Reversing this is normally possible, but requires manual manipulation of the
# branch.
export def drop [
  key: string,  # key to drop
  --branch(-b): string,  # branch to drop the key from
] {
  let filename = $"($key).json"
  let branch = (get-branch-name $branch)

  drop-file-from-branch $filename $branch
}
