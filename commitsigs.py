# commitsigs.py - sign changesets upon commit
#
# Copyright 2009, 2010 Matt Mackall <mpm@selenic.com> and others
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2, incorporated herein by reference.

"""sign changesets upon commit

This extension will use GnuPG or OpenSSL to sign the changeset hash
upon each commit and embed the signature directly in the changelog.

Use 'hg log --debug' to see the extra meta data for each changeset,
including the signature.

You must first select the desired signature scheme::

  [commitsigs]
  scheme = gnupg

The two recognized schemes are ``gnupg`` (the default) and
``openssl``. If you use ``gnupg``, then you normally wont have to
configure other options. However, if ``gpg`` is not in your path, if you have
multiple private keys, or if you want to specify a minimum trust level for
gnupg signatures then you may want to set the following options::

  [commitsigs]
  gnupg.path = mygpg
  gnupg.flags = --local-user me
  # Allowed trust levels (in increasing order): TRUST_UNDEFINED, TRUST_NEVER,
  # TRUST_MARGINAL, TRUST_FULLY, TRUST_ULTIMATE
  gnupg.minimumtrust = TRUST_UNDEFINED

The ``openssl`` scheme requires a little more configuration. You need
to specify the path to your X509 certificate file and to a directory
filled with trusted certificates::

  [commitsigs]
  scheme = openssl
  openssl.certificate = my-cert.pem
  openssl.capath = trusted-certificates

You must use the ``c_rehash`` program from OpenSSL to prepare the
directoy with trusted certificates for use by OpenSSL. Otherwise
OpenSSL wont be able to lookup the certificates.
"""

import os
import tempfile
import subprocess
import binascii
import shlex
import re

from mercurial import (cmdutil, extensions, error,
                       encoding, changelog, scmutil)
from mercurial.node import short, hex, nullid
from mercurial.i18n import _

cmdtable = {}
try:
    from mercurial.utils.dateutil import parsedate, makedate
except (ImportError, AttributeError):
    from mercurial.util import parsedate, makedate
try:
    from mercurial.utils.storageutil import hashrevisionsha1 as revlog_hash
except (ImportError, AttributeError):
    from mercurial.revlog import hash as revlog_hash
try:
    from mercurial import registrar
    command = registrar.command(cmdtable)
except (ImportError, AttributeError):
    command = cmdutil.command(cmdtable)

try:
    from mercurial.metadata import ChangingFiles
except ImportError:
    supportChangingFiles = False
else:
    supportChangingFiles = True

CONFIG = {
    b'scheme': b'gnupg',
    b'gnupg.path': b'gpg',
    b'gnupg.flags': [],
    b'gnupg.minimumtrust': b'TRUST_UNDEFINED',
    b'openssl.path': b'openssl',
    b'openssl.capath': b'',
    b'openssl.certificate': b''
    }

GPG_TRUSTLEVEL = [b'TRUST_UNDEFINED',
                  b'TRUST_NEVER',
                  b'TRUST_MARGINAL',
                  b'TRUST_FULLY',
                  b'TRUST_ULTIMATE']

gpg_signer_pattern = re.compile(b'GOODSIG \w+ (.*)')
openssl_mail_pattern = re.compile(b'subject=.*emailAddress=(.*?)(?:/|$)',
                                  re.MULTILINE)
openssl_cn_pattern = re.compile(b'subject=.*CN=(.*?)(?:/|$)', re.MULTILINE)


def gnupgsign(msg):
    cmd = [CONFIG[b'gnupg.path'], '--detach-sign'] + CONFIG[b'gnupg.flags']
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    sig = p.communicate(msg)[0]
    if not sig:
        raise error.Abort(_(b'no signature created, commit aborted'))
    return binascii.b2a_base64(sig).strip()


def gnupgverify(msg, sig, quiet=False):
    sig = binascii.a2b_base64(sig)
    try:
        fd, filename = tempfile.mkstemp(prefix='hg-', suffix='.sig')
        fp = os.fdopen(fd, 'wb')
        fp.write(sig)
        fp.close()
        stderr = quiet and subprocess.PIPE or None

        cmd = [CONFIG[b'gnupg.path']] + CONFIG[b'gnupg.flags'] + \
            ['--status-fd', '1', '--verify', filename, '-']
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, stderr=stderr)
        out, err = p.communicate(msg)

        trustlevel = 0
        for index, trustvalue in enumerate(GPG_TRUSTLEVEL):
            if trustvalue in out:
                trustlevel = index
                break
        trustok = GPG_TRUSTLEVEL.index(CONFIG[b'gnupg.minimumtrust']) <= trustlevel
        verifyok = b'GOODSIG' in out and trustok

        findSigner = gpg_signer_pattern.search(out)
        signer = None
        if findSigner:
            signer = findSigner.group(1)

        return {b'verifyok': verifyok, b'signer': signer}
    finally:
        try:
            os.unlink(filename)
        except OSError:
            pass


def opensslsign(msg):
    try:
        fd, filename = tempfile.mkstemp(prefix='hg-', suffix='.msg')
        fp = os.fdopen(fd, 'wb')
        fp.write(msg)
        fp.close()

        cmd = [CONFIG[b'openssl.path'], 'smime', '-sign', '-outform', 'pem',
               '-signer', CONFIG[b'openssl.certificate'], '-in', filename]
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        sig = p.communicate()[0]
        return sig
    finally:
        try:
            os.unlink(filename)
        except OSError:
            pass


def opensslverify(msg, sig, quiet=False):
    try:
        fd, filename = tempfile.mkstemp(prefix='hg-', suffix='.msg')
        fp = os.fdopen(fd, 'wb')
        fp.write(msg)
        fp.close()

        cmd = [CONFIG[b'openssl.path'], 'smime',
               '-verify', '-CApath', CONFIG[b'openssl.capath'],
               '-inform', 'pem', '-content', filename]
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        out, err = p.communicate(sig)
        verifyok = err.strip() == 'Verification successful'

        cmd = [CONFIG[b'openssl.path'], 'pkcs7', '-inform', 'PEM',
               '-print_certs']
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        out, err = p.communicate(sig)

        cn = openssl_cn_pattern.search(out)
        mail = openssl_mail_pattern.search(out)
        signer = None
        if cn:
            signer = cn.group(1)
        if mail:
            signer += ' <' + mail.group(1) + '>'

        return {b'verifyok': verifyok, b'signer': signer}
    finally:
        try:
            os.unlink(filename)
        except OSError:
            pass


def chash(manifest, files, desc, p1, p2, user, date, extra):
    """Compute changeset hash from the changeset pieces."""
    user = user.strip()
    if b'\n' in user:
        raise error.RevlogError(_('username %s contains a newline')
                                % repr(user))

    # strip trailing whitespace and leading and trailing empty lines
    desc = b'\n'.join([l.rstrip() for l in desc.splitlines()]).strip(b'\n')

    user, desc = encoding.fromlocal(user), encoding.fromlocal(desc)

    if date:
        parseddate = b'%d %d' % parsedate(date)
    else:
        parseddate = b'%d %d' % makedate()
    extra = extra.copy()
    if b'signature' in extra:
        del extra[b'signature']
    if extra.get(b'branch') in (b'default', b''):
        del extra[b'branch']
    if extra:
        extra = changelog.encodeextra(extra)
        parseddate = b'%s %s' % (parseddate, extra)

    if supportChangingFiles and isinstance(files, ChangingFiles):
        fileList = set(files.added)
        fileList.update(files.merged)
        fileList.update(files.removed)
        fileList.update(files.salvaged)
        fileList.update(files.touched)
        files = fileList

    l = [hex(manifest), user, parseddate] + sorted(files) + [b'', desc]
    text = b'\n'.join(l)
    return revlog_hash(text, p1, p2)


def ctxhash(ctx):
    """Compute changeset hash from a ``changectx``."""
    manifest, user, date, files, desc, extra = ctx.changeset()
    p1, p2 = ([p.node() for p in ctx.parents()] + [nullid, nullid])[:2]
    date = (int(date[0]), date[1])
    return chash(manifest, files, desc, p1, p2, user, date, extra)


@command(b'verifysigs',
    [(b'', b'only-heads', False, _(b'only verify heads'))],
    _(b'[--only-heads] [REV]...')
    )
def verifysigs(ui, repo, *revrange, **opts):
    """verify manifest signatures

    Verify repository heads, the revision range specified or all
    changesets. The return code is one of:

    - 0 if all changesets had valid signatures
    - 1 if there were a changeset without a signature
    - 2 if an exception was raised while verifying a changeset
    - 3 if there were a changeset with a bad signature

    The final return code is the highest of the above.
    """
    if opts.get('only_heads'):
        revs = repo.heads()
    elif not revrange:
        revs = range(len(repo))
    else:
        revs = scmutil.revrange(repo, revrange)

    retcode = 0
    for rev in revs:
        ctx = repo[rev]
        h = ctxhash(ctx)
        extra = ctx.extra()
        sig = extra.get(b'signature')
        if not sig:
            msg = _(b'** no signature')
            ui.write(b'%d:%s: %s\n' % (ctx.rev(), ctx, msg))
            retcode = max(retcode, 1)
            continue
        else:
            ui.debug(_(b'signature: %s\n') % sig)

        try:
            scheme, sig = sig.split(b':', 1)
            verifyfunc = sigschemes[scheme][1]
            result = verifyfunc(hex(h), sig, quiet=True)
            if result[b'verifyok']:
                msg = _(b'good %s signature from %s') % (scheme,
                        result[b'signer'])
            else:
                msg = _(b'** bad %s signature on %s') % (scheme, short(h))
                retcode = max(retcode, 3)
        except Exception as e:
            ui.write(_(b'** exception while verifying signature on %s\n' % short(h)))
            raise e

        ui.write(b'%d:%s: %s\n' % (ctx.rev(), ctx, msg))
    return retcode


def verifyallhook(ui, repo, node, **kwargs):
    """verify changeset signatures

    This hook is suitable for use as a ``pretxnchangegroup`` hook. It
    will verify that all pushed changesets carry a good signature. If
    one or more changesets lack a good signature, the push is aborted.
    """
    uisetup(ui)
    ctx = repo[node]
    if verifysigs(ui, repo, b'%s:' % node) > 0:
        raise error.Abort(_('could not verify all new changesets'))


def verifyheadshook(ui, repo, node, **kwargs):
    """verify signatures in repository heads

    This hook is suitable for use as a ``pretxnchangegroup`` hook. It
    will verify that all heads carry a good signature after push. If
    one or more changesets lack a good signature, the push is aborted.
    """
    uisetup(ui)
    ctx = repo[node]
    if verifysigs(ui, repo, True, '%s:' % node, only_heads=True) > 0:
        raise error.Abort(_('could not verify all new changesets'))


sigschemes = {b'gnupg': (gnupgsign, gnupgverify),
              b'openssl': (opensslsign, opensslverify)}


def uisetup(ui=None):
    for key in CONFIG:
        val = CONFIG[key]
        uival = ui.config(b'commitsigs', key, val)
        if isinstance(val, list) and not isinstance(uival, list):
            CONFIG[key] = shlex.split(uival.decode("utf-8"))
        else:
            CONFIG[key] = uival
    if CONFIG[b'scheme'] not in sigschemes:
        raise error.Abort(_(b'unknown signature scheme: %s')
                         % CONFIG[b'scheme'])
    if CONFIG[b'gnupg.minimumtrust'] not in GPG_TRUSTLEVEL:
        raise error.Abort(_(b'unknown gnupg trustlevel: %s')
                         % CONFIG[b'gnupg.minimumtrust'])


def extsetup(ui):

    def add(orig, self, manifest, files, desc, transaction,
            p1=None, p2=None, user=None, date=None, extra={},
            *args):
        h = chash(manifest, files, desc, p1, p2, user, date, extra)
        scheme = CONFIG[b'scheme']
        signfunc = sigschemes[scheme][0]
        extra[b'signature'] = b'%s:%s' % (scheme, signfunc(hex(h)))
        return orig(self, manifest, files, desc, transaction,
                    p1, p2, user, date, extra)

    extensions.wrapfunction(changelog.changelog, 'add', add)
