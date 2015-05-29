"""
This module allows users to export "collections".
"""
# Font Manager, a font management application for the GNOME desktop
#
# Copyright (C) 2009, 2010 Jerry Casiano
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to:
#
#    Free Software Foundation, Inc.
#    51 Franklin Street, Fifth Floor
#    Boston, MA 02110-1301, USA.

# Disable warnings related to gettext
# pylint: disable-msg=E0602

import os
import glib
import glob
import gtk
import logging
import shutil
import cPickle
import shelve
import subprocess
import time

from os.path import exists, join, realpath, splitext

from constants import HOME, CACHE_DIR, DESKTOP_DIR, TMP_DIR, T1_EXTS
from utils.common import create_archive_from_folder

SAMPLER_CACHE   =   join(CACHE_DIR, 'sampler.cache')


class Export(object):
    """
    Export a collection.
    """
    def __init__(self, objects):
        self.objects = objects
        self.dialog = self.objects['ExportDialog']
        self.manager = self.objects['FontManager']
        self.outdir = DESKTOP_DIR
        self.current_collection = None
        self.workdir = None
        self.archtype = None
        self.pangram = None
        self.fontsize = None
        try:
            import reportlab
            logging.info\
            ('Found ReportLab Toolkit Version %s' % reportlab.Version)
            self.reportlab = True
        except ImportError:
            self.reportlab = False
        self.objects['IncludeSampler'].set_sensitive(self.reportlab)
        self.objects['ExportAsPDF'].set_sensitive(self.reportlab)
        if not self.reportlab:
            tooltip = _('This feature requires the Report Lab Toolkit')
            self.objects['IncludeSampler'].set_tooltip_text(tooltip)
            self.objects['ExportAsPDF'].set_tooltip_text(tooltip)
        self.objects['ExportFileChooser'].connect('current-folder-changed',
                                                        self._on_dest_set)
        self.objects['ExportFileChooser'].set_current_folder(DESKTOP_DIR)
        self.objects['ExportAsArchive'].connect('toggled',
                                                    self._update_sensitivity)
        self.objects['ExportAsPDF'].connect('toggled', self._update_sensitivity)
        self.objects['ExportTo'].connect('toggled', self._update_sensitivity)

    def run(self):
        """
        Show export dialog.
        """
        self.current_collection = self.objects['Treeviews'].current_collection
        self.archtype = self.objects['Preferences'].archivetype
        self.pangram = self.objects['Preferences'].pangram
        self.fontsize = self.objects['Preferences'].fontsize
        response = self.dialog.run()
        self.dialog.hide()
        while gtk.events_pending():
            gtk.main_iteration()
        if response:
            self.process_export()

    def _on_dest_set(self, widget):
        """
        Check if folder selection is valid, display a warning if it's not.
        """
        new_folder = self.objects['ExportFileChooser'].get_current_folder()
        if os.access(new_folder, os.W_OK):
            self.outdir = new_folder
        else:
            markup = '<span weight="light" size="small" foreground="red"><tt>' \
            + _('Selected folder must be writeable') + '</tt></span>'
            self.objects['ExportPermissionsWarning'].set_markup(markup)
            glib.timeout_add_seconds(3, self._reset_filechooser, widget)
            glib.timeout_add_seconds(6, self._dismiss_warning)
        return

    @staticmethod
    def _reset_filechooser(widget):
        """
        Reset filechooser to default folder.
        """
        widget.set_current_folder(join(HOME, "Desktop"))
        return False

    def _dismiss_warning(self):
        """
        Hide warning.
        """
        self.objects['ExportPermissionsWarning'].set_text('')
        return False

    def process_export(self):
        """
        Export selected collection.
        """
        self.workdir = join(TMP_DIR, self.current_collection)
        if exists(TMP_DIR):
            os.unlink(TMP_DIR)
        if exists(self.workdir):
            shutil.rmtree(self.workdir, ignore_errors=True)
        os.mkdir(TMP_DIR)
        os.mkdir(self.workdir)
        if self.objects['ExportAsArchive'].get_active():
            self._do_work_copy(self._get_filelist())
            if self.objects['IncludeSampler'].get_active():
                self._do_pdf_setup()
            create_archive_from_folder(self.current_collection, self.archtype,
                                                    self.outdir, self.workdir)
            self._do_cleanup()
        elif self.objects['ExportAsPDF'].get_active():
            self._do_pdf_setup(self._get_filelist(), outp = self.outdir)
            self._do_cleanup()
        elif self.objects['ExportTo'].get_active():
            self._do_direct_copy(self._get_filelist())
        if exists(TMP_DIR):
            shutil.rmtree(TMP_DIR, ignore_errors=True)
        os.chdir(HOME)
        return

    def _get_filelist(self):
        """
        Return a list of filepaths for currently selected collection.
        """
        filelist = []
        for family in self.manager.list_families_in(self.current_collection):
            for val in self.manager[family].styles.itervalues():
                filelist.append(realpath(val['filepath']))
        return filelist

    def _do_cleanup(self):
        """
        Remove temporary directory.
        """
        if exists(self.workdir):
            shutil.rmtree(self.workdir, ignore_errors=True)
            self.workdir = None
        return

    def _do_work_copy(self, filelist):
        """
        Copy files to a temporary directory.
        """
        total = len(filelist)
        progress = 0
        self.objects.set_sensitive(False)
        self.objects['ProgressBar'].set_text(_('Copying files...'))
        for path in set(filelist):
            shutil.copy(path, self.workdir)
            # Try to include .afm, .pfm files for Type 1 fonts
            if path.endswith(T1_EXTS):
                metrics = splitext(path)[0] + '.*'
                for path in glob.glob(metrics):
                    shutil.move(path, self.workdir)
            progress += 1
            self.objects.progress_callback(None, total, progress)
        self.objects['ProgressBar'].set_text('')
        self.objects.set_sensitive(True)
        return

    def _do_direct_copy(self, filelist):
        """
        Copy files directly to selected folder.
        """
        total = len(filelist)
        progress = 0
        self.objects.set_sensitive(False)
        self.objects['ProgressBar'].set_text(_('Copying files...'))
        self.workdir = join(self.outdir, self.current_collection)
        if not exists(self.workdir):
            os.mkdir(self.workdir)
        for path in set(filelist):
            shutil.copy(path, self.workdir)
            # Try to include .afm, .pfm files for Type 1 fonts
            if path.endswith(T1_EXTS):
                metrics = splitext(path)[0] + '.*'
                for path in glob.glob(metrics):
                    shutil.move(path, self.workdir)
            progress += 1
            self.objects.progress_callback(None, total, progress)
        self.objects['ProgressBar'].set_text('')
        self.objects.set_sensitive(True)
        return

    def _do_pdf_setup(self, inp = None, outp = None):
        """
        Build PDF sample sheet from given files.

        Keyword Arguments

        input -- a python list of filepaths or a folder containing font files
        output -- folder to store reulting pdf in
        """
        if inp is None:
            inp = self.workdir
        if outp is None:
            outp = self.workdir
        if exists(SAMPLER_CACHE):
            os.unlink(SAMPLER_CACHE)
        cache = shelve.open(SAMPLER_CACHE, protocol=cPickle.HIGHEST_PROTOCOL)
        cache['collection'] = self.current_collection
        cache['fontlist'] = inp
        cache['outfile'] = join(outp, '%s.pdf' % self.current_collection)
        cache.close()
        font_sampler = join('/usr/local', 'bin/font-sampler')
        sampler = subprocess.Popen([font_sampler])
        # Wait for font-sampler to finish
        while sampler.poll() is None:
            # Prevent loop from hogging cpu
            time.sleep(0.5)
            # Avoid the main window becoming unresponsive
            while gtk.events_pending():
                gtk.main_iteration()
            continue
        return

    def _update_sensitivity(self, unused_widget):
        if not self.objects['ExportAsArchive'].get_active():
            self.objects['IncludeSampler'].set_sensitive(False)
        else:
            if self.reportlab:
                self.objects['IncludeSampler'].set_sensitive(True)
        return