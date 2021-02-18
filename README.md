# Eviction Tracker

Currently helping verify detainer warrant data for middle Tennessee - via Middle TN DSA - Red Door Collective

## Features

### Phone Number Verification

🚧 [Under Construction](/projects/1) 🚧 

## Development

### Setup

#### Nix

Nix is a tool we use to ensure reproducable builds and deployments. Python's default build and deployment system is notoriously tricky.
We've elected to use Nix instead to ease setup. Nix can be used for installing and deploying multiple languages, which may end up being useful for this project.

##### Install Nix

Please follow the instructions to install nix on their website https://nixos.org/download.html#nix-quick-install (Please ignore instructions regarding **NixOS** - that's a whole new operating system).

##### Using Nix

To work with the same python version as everyone else working on this project, you'll need to make sure you're in the `nix-shell` first.

1. Check that you're in the same directory as `shell.nix`
2. Type `nix-shell` and hit enter
3. Wait for necessary dependencies to install from the internet to your machine

You'll get a new prompt that looks like:

```
[nix-shell:~/some/path/eviction-tracker]$ 
```

Now you're ready to run `python` and `ipython`! You can escape the `nix-shell` at any time by holding ctrl pressing the D key or typing `exit` and pressing enter.

### Using a REPL

REPL (Read Eval Print Loop) is a concept implemented in many programming languages. If you've never written python before, we recommend spending an afternoon on [these basics](https://developers.google.com/edu/python). You'll interact with a REPL in those courses. 

While in a [Nix Shell](#using-nix), launch the IPython shell like so:

```
ipython
```

And now, you can write python code with any of our libraries!

### Running scripts

While in a [Nix Shell](#using-nix), run `python src/prepare-numbers.py` or `python src/name-of-my-own-script.py` to run python code you've written in a `.py` file.

### Verifying phone numbers

**Note:** this code is changing fast, and the docs might be out-of-date.

While in a [Nix Shell](#using-nix), run `python src/prepare-numbers.py 'detainer-warrants_15-02-2020'`.
