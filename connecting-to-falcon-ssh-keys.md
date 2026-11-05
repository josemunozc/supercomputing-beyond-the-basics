---
title: 'Connecting to Falcon - SSH keys'
teaching: 25
exercises: 15
---

:::::::::::::::::::::::::::::::::::::: questions 

- How can I connect to Falcon without typing my password every time?
- What do the public and private keys do, and which one can I share?
- How can I make connections quicker and safer to use?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Create an SSH key pair and protect it with a passphrase.
- Install the public key on Falcon and test it.
- Use an SSH config file to connect with a short name.
- Use ssh-agent with a time limit so you type your passphrase less often.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: callout

Detailed instructions

This episode is a guided practical. The complete step-by-step instructions,
are in our [SSH keys documentation page][arcca-docs-ssh-keys]. Keep
it open: you will need it for the exact commands, and it is the page to come
back to after the course.

::::::::::::::::::::::::::::::::::::::::::::::::

## Why bother?

Our researcher has a Python script that is slow, and before we can do anything
about that she needs to get onto Falcon. Count how many times a password is
typed in an ordinary working session:

```bash
ssh c.myuser@falconlogin.cf.ac.uk              # password
scp sweep.py c.myuser@falconlogin.cf.ac.uk:.   # password again
ssh c.myuser@falconlogin.cf.ac.uk              # and again after a dropped connection
```

Later in the day we will use tools such as rsync and tmux, which
all open their own connections. SSH keys remove the repeated password prompts,
and they are also harder to steal than a password, because the secret part
never leaves your computer. SSH keys can also be used to work with other
useful applications like VS Code.

## How do keys work?

A key pair is two files created together:

- the public key goes on Falcon and is not secret, like a padlock you can hand out freely;
- the private key stays on your computer, like the only key that opens the padlock.

When you connect, Falcon challenges your computer to prove it holds the private
key matching the public key on file. The private key itself is never sent.

:::::::::::::::::::::::::::::::::::::: callout

Never share your private key

Anyone who has your private key can pretend to be you on Falcon. The passphrase
you set protects the file if it is ever copied. Only the file ending in .pub is
copied anywhere.

::::::::::::::::::::::::::::::::::::::::::::::::

## Creating a key pair

Open Terminal (Mac) or PowerShell (Windows) and run ssh-keygen. We choose a modern key
type, and a file name that says what the key is for:

```bash
ssh-keygen -t ed25519
```

```output
Generating public/private ed25519 key pair.
Enter file in which to save the key (/Users/myuser/.ssh/id_ed25519): /Users/myuser/.ssh/id_ed25519_falcon
Enter passphrase for "/Users/myuser/.ssh/id_ed25519_falcon" (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /Users/myuser/.ssh/id_ed25519_falcon
Your public key has been saved in /Users/myuser/.ssh/id_ed25519_falcon.pub
```

Choose a passphrase you will remember. Nothing appears on screen while you type it.

:::::::::::::::::::::::::::::::::::::: challenge

Challenge: which file goes where?

ssh-keygen created two files, id_ed25519_falcon and id_ed25519_falcon.pub.

Which one is copied to Falcon?
Which one must never leave your computer?

A colleague emails you "here is my key for Falcon" and attaches id_ed25519_falcon. What has gone wrong?

::::::::::::::::::::::::::::::::::::: solution

- The public key, id_ed25519_falcon.pub.
- The private key, id_ed25519_falcon.
- They sent their private key. Anyone who receives it (and cracks or guesses the passphrase,
  if there is one) can log in as them. They should delete the email, remove the matching
  public key from ~/.ssh/authorized_keys on Falcon and create a new key pair.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::


## Installing the public key on Falcon

Falcon does not trust the key yet, so this one step uses your password.
On a Mac or Linux, ssh-copy-id does the work:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_falcon.pub c.myuser@falconlogin.cf.ac.uk
```

On Windows, use the PowerShell command in the documentation page, because
`ssh-copy-id` does not exist there.

Now test it. You should be asked for the passphrase of your key (not your 
Falcon password):

```bash
ssh -i ~/.ssh/id_ed25519_falcon c.myuser@falconlogin.cf.ac.uk
```

```output
Enter passphrase for key '/Users/myuser/.ssh/id_ed25519_falcon':
....
[c.myuser@cfl2 ~]$
```

## A short name with an SSH config file

Typing the key path and the long host name every time is tedious. An SSH
config file stores them under a short name. Create `~/.ssh/config` (on
Windows, `C:\Users\myuser\.ssh\config`) with:

```text
Host falcon
    HostName falconlogin.cf.ac.uk
    User c.myuser
    IdentityFile ~/.ssh/id_ed25519_falcon
    IdentitiesOnly yes
    ServerAliveInterval 60
```

```bash
ssh falcon
```

The same name works for scp, rsync and VS Code.

:::::::::::::::::::::::::::::::::::::: challenge

Challenge: connect with a short name

- Create the config entry above with your own username.
- From your own computer (not on Falcon), run a single command on Falcon without
  opening a shell and show which login node you reached.
- Copy `sweep.py` to your home directory on Falcon with scp, using the short name.

::::::::::::::::::::::::::::::::::::: solution

```bash
ssh falcon hostname
scp sweep.py falcon:.
```

If a command still asks for your Falcon password, the key was not accepted.
See the troubleshooting challenge below.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

Typing the passphrase less often: ssh-agent

A passphrase on every connection gets tedious. An SSH agent keeps your unlocked key
in memory so you type the passphrase once. Give the key a lifetime, so the agent
forgets it after a while:

```bash
ssh-add -t 8h ~/.ssh/id_ed25519_falcon
ssh-add -l
```

After eight hours SSH asks for the passphrase again. This is intentional: it
limits how long an unlocked key sits in memory, and it means you keep remembering
the passphrase. On a Mac we do not use `--apple-use-keychain`, because that would
store the passphrase permanently and you would never need to type it. Windows needs
the agent service switched on first, which is covered in the documentation page.

:::::::::::::::::::::::::::::::::::::: challenge

Challenge: why does it still ask?

Each of these happens after following the steps above. What is the most likely
cause, and what would you check first?

- `ssh falcon` asks for your Falcon password, not the key passphrase.
- `ssh falcon` says Permission denied (publickey).
- `ssh-add` says *Could not open a connection to your authentication agent*.
- You type a passphrase, but the prompt is empty and you think nothing is happening.

::::::::::::::::::::::::::::::::::::: solution

- The key was not accepted. Check that the .pub file (not the private key) was
  installed, that the username is right and that IdentityFile points to the
  private key. Add `-v` to see which keys SSH offers. Use `-vvv` for more details.
- Falcon rejected the key and has no other method to offer. Same checks as above,
  and check the permissions of ~/.ssh (700) and ~/.ssh/authorized_keys (600) on Falcon.
- The agent is not running. Start it (see the documentation page for your operating system).
- Nothing is echoed while you type a passphrase, so this is normal. Type it and press Enter.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::: keypoints

- A key pair has a public key (installed on Falcon, safe to share) and a private key (never shared).
- Protect the private key with a passphrase.
- An SSH config entry gives the connection a short name that `ssh`, `scp`, `rsync` and VS Code all understand.
- Add the key to an agent with `-t` so the passphrase is remembered for a limited time.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: instructor

Instructor notes

Timing. About 25 minutes of live coding and 15 of exercises. Do the "before"
demo first (type the password three times) so the gain is visible.

Mixed audience. Demonstrate on your own system, but say aloud what is different
on Windows (paths, no ssh-copy-id, agent service) and have a Windows machine or
screenshots ready for PuTTY and MobaXterm. Ask PuTTY and MobaXterm users to follow
the documentation page while you demonstrate the concepts.

Common problems.

- Nothing is shown while typing a passphrase, and people think the terminal is frozen.
- Confusing the Falcon password with the key passphrase.
- Windows: Notepad saves the config file as config.txt; the .ssh folder does not
  exist yet; paths use backslashes.
- PuTTYgen: the Save public key button produces a format Falcon cannot read.
- MobaXterm: its local terminal has a different home directory from Windows.
- Someone sends or pastes the private key. Treat it as a teaching moment and have them regenerate the key.

Fallback. The rest of the lesson does not depend on keys. If someone cannot get them working in the time, they can keep using their password and fix it afterwards with the documentation page or by contacting support.

Fallback. The rest of the lesson does not depend on keys. If someone cannot get them
working in the time, they can keep using their password and fix it afterwards with the
documentation page or by contacting support.
::::::::::::::::::::::::::::::::::::::::::::::::
