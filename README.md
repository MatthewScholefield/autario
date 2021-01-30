# Autario

*A command line application to automate your life*

Autario is a tool used to keep track of various things in your
life so that you can focus on what matters most. It currently
handles the following things:

 - Keeping track of todo items / tasks and deadlines

**Key features:**

 - Super easy, dynamic syntax
 - Painless, automatic syncing across multiple devices
 - Minimalistic task views that only focuses on what needs to be done right now
 - Separation between leisure tasks and work tasks

## Usage

Interact with Autario through the `auta` command.

**Create:**
```bash
auta create buy groceries
auta create implement web-based form +frontend due:thu  # Use +tag or due:<date> identifiers
auta create lab 6 +cs233 due:1week.2days
auta create weekly homework +cs357 due:mon.8pm recur:weekly
```

**List:**
```bash
auta list
auta list --all
auta list +cs357
```

**Done:**
```bash
auta 12 15 done  # Marks tasks 12 and 15 as done
auta +cs357 done  # Marks all tasks with tag +cs357 as done
```

**Info:**
```bash
auta 9 info # Views info about task 9
```

### Synchronization

Setup synchronization as follows:

```bash
auta link  # Connects local instance to server
auta link export auth.json  # Export key

# Copy key to another platform securely...

auta link import auta.json
```

#### Technical details

Cross device synchronization works by serializing to JSON and encrypting
symmetrically using 128 bit CFB [Twofish encryption](https://en.wikipedia.org/wiki/Twofish)
stored in [Blobse](https://github.com/MatthewScholefield/blobse). In addition
to storing the encrypted blob, it also stores a small change uuid that it
fetches first to reduce data transferred on cache hits.

Whenever the executable starts and hasn't updated in the last 30 seconds,
it checks if its change uuid matches the server's change uuid. If not, it
fetches and decrypts the new blob.

## Installation

Find static Linux executables on the [releases page](https://github.com/MatthewScholefield/autario/releases).
Alternatively, find artifacts within the CI job of the latest commit.

### Compiling

This project uses [Nim](nim-lang.org/). It can be compile using `nimble`:

```bash
nimble build
```

## Formatting Details

### Due Time


```bash
due:2days.1_hour.3minutes
"due:2 days.1 hour"
due:friday.10am
due:30th.2pm

recur:weekly
recur:monthly
recur:wed.8pm
recur:wednesdays.15:30
recur:21st.3pm
```

## Similar Tools

Here's a list of similar tools and their benefits and drawbacks:

 - [Taskwarrior](https://taskwarrior.org/)
    - Benefits: Easy interface, cross-device sync, lots of features
    - Downsides: Buggy cross-device recurring tasks, no auto-sync, too many tasks clutter the view, no native API
 - [Org Mode](https://orgmode.org/)
    - Benefits: Lots of features, customizable with elisp
    - Downsides: 200 page reference manual, no cross-device sync, not user-friendly
