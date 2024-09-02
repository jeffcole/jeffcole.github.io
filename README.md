# jeffcole.github.io

This is the code for [my homepage]. I started it with [proteus-middleman].

## Setup

Install Ruby with [asdf]:

```sh
asdf install
```

Install the version of Bundler [used to bundle gems]:

```sh
gem install bundler -v '1.13.7'
```

Install dependencies:

```sh
bundle install
```

Run the server:

```sh
bundle exec middleman
```

## Deploy to GitHub Pages

```sh
bundle exec middleman deploy
```

## License

Copyright © 2024 Jeff Cole. See [LICENSE](LICENSE) for more information.

[my homepage]: http://jeff-cole.com
[proteus-middleman]: https://github.com/thoughtbot/proteus-middleman
[asdf]: https://asdf-vm.com
[used to bundle gems]: https://github.com/rubygems/bundler/issues/6865#issuecomment-452831908
