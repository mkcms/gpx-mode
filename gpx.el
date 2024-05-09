;;; gpx.el --- Major mode for GPX files         -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Michał Krzywkowski

;; Author: Michał Krzywkowski <k.michal@zoho.com>
;; Keywords: data, tools
;; Version: n/a
;; Homepage: https://github.com/mkcms/gpx-mode
;; Package-Requires: ((emacs "27.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;
;;; gpx.el
;;
;; Package that provides a major mode for viewing [GPX] files.
;;
;; The major mode displays .gpx files in a human readable format.  When
;; the major mode is active, the buffer displays various statistics about
;; the file and lists all the tracks/segments found in the file.
;;
;; The displayed information includes total length, time of start/end,
;; average speed, max speed, etc.
;;
;; It also supports drawing the routes found in the file.  You can click
;; on a button below a track and it will open a web browser showing that
;; route on a map.
;;
;; You can also display elevation profile for each track.  To do that,
;; click on the [Show elevation profile] button below a track, this will
;; insert the elevation profile image below the track.
;;
;;
;;; Installation
;;
;; You need to install [gpxinfo] program in order to convert the files.
;;
;; Additionally, if you want to be able to draw the routes on a map, you
;; need to install [folium].
;;
;; In order to display elevation profiles, you need to install
;; [matplotlib] Python library.
;;
;; These dependencies can be installed on Debian-based systems with:
;;
;; 	sudo apt-get install gpxinfo python3-folium python3-matplotlib
;;
;; You can also install them via pip:
;;
;; 	pip install gpx-cmd-tools folium matplotlib
;;
;;
;; [GPX]: https://wiki.openstreetmap.org/wiki/GPX
;;
;; [gpxinfo]: https://github.com/tkrajina/gpx-cmd-tools
;;
;; [folium]: https://github.com/python-visualization/folium
;;
;; [matplotlib]: https://matplotlib.org/

;;; Code:

(require 'browse-url)
(require 'rx)

(defgroup gpx nil "Major mode for GPX files."
  :group 'data
  :group 'tools)


;; Conversion

(defvar gpx-conversion-function #'gpx-convert-with-gpxinfo
  "Function used to convert the current buffer into human readable format.
It should be callable with no arguments and should replace the
contents of the current buffer with some human readable version
of the GPX file.")

(defcustom gpx-gpxinfo-executable (or (executable-find "gpxinfo") "gpxinfo")
  "The gpxinfo executable for pretty-printing a GPX buffer."
  :type 'file)

(defun gpx-convert-with-gpxinfo ()
  "Convert the GPX XML in the current buffer into human readable format."
  (erase-buffer)
  (let (res)
    (condition-case err
        (setq res (call-process gpx-gpxinfo-executable nil (current-buffer) nil
                                (buffer-file-name)))
      (error (setq res err)))
    (pcase res
      ('0)
      ((pred integerp)
       (insert (format "Error: %s failed with exit code %s"
                       gpx-gpxinfo-executable res)))
      (_
       (insert (format "Error when running %s: %s"
                       gpx-gpxinfo-executable res))))))

(defvar gpx--gpxinfo-track-regexp
  (rx line-start (one-or-more space)
      (group-n 1
        "Track #" (group-n 2 (one-or-more digit))
        (one-or-more any)
        "Segment #" (group-n 3 (one-or-more digit))))
  "A regexp to match track/segment dump in human-readable GPX buffer.
After inserting human-readable GPX file in the buffer, this
regexp is searched for repeatedly to find routes.  It should
match a line that begins a track/segment dump.  Below this line,
a button is inserted to show that route.

It must contain three groups:
1. Must be the entire header, with whitespace trimmed for imenu.
2. Must contain the track number.
3. Must contain the segment number.")

(defun gpx--collect-routes ()
  "Collect routes from the current buffer after conversion.
This scans the buffer using `gpx--gpxinfo-track-regexp', and
returns a list, where every element is:

    (STRING MARKER (TRACK . SEGMENT))

Where:
STRING is the matched route string,
MARKER is a marker at the buffer position where it was found,
TRACK and SEGMENT are the indices of the track and segment in the file."
  (save-excursion
    (cl-loop
     initially (goto-char (point-min))
     while (re-search-forward gpx--gpxinfo-track-regexp nil t)
     collect `(,(match-string-no-properties 1)
               ,(move-marker (make-marker) (match-beginning 1))
               (,(string-to-number (match-string 2))
                . ,(string-to-number (match-string 3)))))))


;; Show route on map stuff

(defvar gpx-show-map-function #'gpx-show-map-gpx2html
  "Function used to show map and some route.
It accepts three arguments, the filename, track number and
segment number.")

(defvar gpx-gpx2html-script
  (expand-file-name "gpx2html.py"
                    (file-name-directory (or load-file-name
                                             (buffer-file-name))))
  "The python script to call to generate a HTML file which draws a route.
The script is passed 4 arguments: input GPX file, track number,
segment number and output HTML file.")

(defun gpx-show-map-gpx2html (filename track segment)
  "Open browser showing TRACK and SEGMENT route in FILENAME.
This should be used as `gpx-show-map-function'."
  (let ((output (make-temp-file
                 (format "emacs-track-%d-segment-%d" track segment)
                 nil ".html"))
        exit-code output-buf)
    (with-temp-buffer
      (setq exit-code
            (call-process (or (executable-find "python3")
                              (executable-find "python"))
                          nil (current-buffer) nil
                          gpx-gpx2html-script filename
                          (number-to-string track) (number-to-string segment)
                          output))
      (unless (equal exit-code 0)
        (setq output-buf (current-buffer))
        (with-current-buffer (get-buffer-create "*gpx gpx2html error*")
          (text-mode)
          (read-only-mode 1)
          (let ((inhibit-read-only t))
            (replace-buffer-contents output-buf))
          (display-buffer (current-buffer)))
        (error "%s failed for %s %s %s" gpx-gpx2html-script filename
               track segment)))
    (browse-url (concat "file://" output))))

(defun gpx-show-map (route)
  "Show map for route ROUTE.
ROUTE should be either a cons cell (TRACK . SEGMENT) which should
be the indices of track/segment to show, or an overlay with
properties \\='gpx-track and \\='gpx-segment that mean the same."
  (interactive
   (list
    (let ((routes (gpx--collect-routes)))
      (caddr
       (assoc (completing-read "Show map for route: " routes nil t) routes)))))
  (let ((buffer (current-buffer))
        track segment)
    (if (overlayp route)
        (progn
          (setq buffer (overlay-buffer route))
          (setq track (overlay-get route 'gpx-track))
          (setq segment (overlay-get route 'gpx-segment)))
      (setq track (car route) segment (cdr route)))
    (funcall gpx-show-map-function (buffer-file-name buffer) track segment)))

(define-button-type 'gpx-show-map
  'action #'gpx-show-map
  'keymap (let ((map (make-sparse-keymap)))
            (define-key map [mouse-1] #'push-button)
            map)
  'mouse-face 'highlight
  'help-echo "mouse-1, RET: Show map")


;; Show elevation profile for a route

(defvar gpx-generate-elevation-profile-function
  #'gpx-generate-elevation-profile-default
  "Function used to generate an elevation profile of some route.
It accepts three arguments, the filename, track number and
segment number and should return an image (from `create-image').")

(defvar gpx-plot-track-elevation-script
  (expand-file-name "plot_track_elevation.py"
                    (file-name-directory (or load-file-name
                                             (buffer-file-name))))
  "The python script to call to generate an image with an elevation profile.
The script is passed 4 arguments: input GPX file, track number,
segment number and output image file.")

(defun gpx-generate-elevation-profile-default (filename track segment)
  "Generate an image with an elevation profile of TRACK+SEGMENT in FILENAME.
This should be used as `gpx-generate-elevation-profile-function'."
  (let ((output (make-temp-file
                 (format "emacs-gpx-elevation-profile-%d-segment-%d"
                         track segment)
                 nil ".png"))
        exit-code output-buf)
    (with-temp-buffer
      (setq exit-code
            (call-process (or (executable-find "python3")
                              (executable-find "python"))
                          nil (current-buffer) nil
                          gpx-plot-track-elevation-script filename
                          (number-to-string track) (number-to-string segment)
                          output))
      (unless (equal exit-code 0)
        (setq output-buf (current-buffer))
        (with-current-buffer (get-buffer-create "*gpx script error*")
          (text-mode)
          (read-only-mode 1)
          (let ((inhibit-read-only t))
            (replace-buffer-contents output-buf))
          (display-buffer (current-buffer)))
        (error "%s failed for %s %s %s"
               gpx-plot-track-elevation-script filename
               track segment)))
    (create-image output)))

(defun gpx-show-elevation-profile (route)
  "Show elevation profile for route ROUTE.
ROUTE should be either a cons cell (TRACK . SEGMENT) which should
be the indices of track/segment to show, or an overlay with
properties \\='gpx-track and \\='gpx-segment that mean the same."
  (interactive
   (list
    (let ((routes (gpx--collect-routes)))
      (caddr
       (assoc
        (completing-read "Show elevation profile for route: " routes nil t)
        routes)))))
  (let (buffer track segment image already-inserted
               (modified (buffer-modified-p)))
    (if (overlayp route)
        (setq buffer (overlay-buffer route)
              track (overlay-get route 'gpx-track)
              segment (overlay-get route 'gpx-segment)
              already-inserted (overlay-get route 'gpx--eprofile-inserted))
      (setq buffer (current-buffer) track (car route) segment (cdr route)))
    (unless already-inserted
      (setq image
            (funcall gpx-generate-elevation-profile-function
                     (buffer-file-name buffer) track segment))
      (cond
       ((and (overlayp route) (display-images-p))
        (progn
          (overlay-put route 'gpx--eprofile-inserted t)
          (goto-char (overlay-start route))
          (forward-line 1)
          (let ((inhibit-read-only t))
            (open-line 1)
            (insert-image image)
            (restore-buffer-modified-p modified))))
       ((display-images-p)
        (with-current-buffer (get-buffer-create "*gpx elevation profile*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert-image image)
            (display-buffer (current-buffer)))))
       ((image-property image :file)
        (browse-url (concat "file://" (image-property image :file))))
       (t (error "Can't display elevation profile"))))))

(define-button-type 'gpx-show-elevation-profile
  'action #'gpx-show-elevation-profile
  'keymap (let ((map (make-sparse-keymap)))
            (define-key map [mouse-1] #'push-button)
            map)
  'mouse-face 'highlight
  'help-echo "mouse-1, RET: Show elevation profile")


;; Major mode

(defvar gpx-mode-font-lock-keywords
  `(("\\_<\\(File\\): +\\(.*\\)"
     (1 font-lock-keyword-face)
     (2 font-lock-function-name-face))

    ("\\(Author\\|Email\\|GPX \\(?:description\\|name\\)\\): \\(.*\\)"
     (1 font-lock-keyword-face)
     (2 font-lock-comment-face))

    "Avg distance between points"
    "Avg speed"
    "Ended"
    "File"
    "Length 2D"
    "Length 3D"
    "Max speed"
    "Moving time"
    "Points"
    "Started"
    "Stopped time"
    "Total downhill"
    "Total uphill"

    "Track" "Segment"

    (,(rx (seq symbol-start
               (one-or-more digit) ":" (one-or-more digit)
               ":" (one-or-more digit)
               symbol-end))
     (0 font-lock-constant-face)))
  "Expressions to highlight in `gpx-mode'.")

(defun gpx-mode--postprocess-add-buttons ()
  "Scan buffer for track dumps and add buttons that will show those tracks."
  (pcase-dolist (`(,_ ,marker (,track . ,segment)) (gpx--collect-routes))
    (goto-char marker)
    (let ((indent (current-indentation)))
      (forward-line 1)
      (insert (make-string indent ?\ ))
      (insert-button "[Show map]"
                     'type 'gpx-show-map
                     'gpx-track track
                     'gpx-segment segment)
      (insert " ")
      (insert-button "[Show elevation profile]"
                     'type 'gpx-show-elevation-profile
                     'gpx-track track
                     'gpx-segment segment)
      (insert "\n\n"))))

(defvar gpx-mode-postprocessing-functions '(gpx-mode--postprocess-add-buttons)
  "Hook called after converting a buffer into human readable format.")

(defun gpx-mode--revert-buffer (&optional ignore-auto noconfirm)
  "Revert current buffer using `gpx-gpxinfo-executable' for GPX conversion.
IGNORE-AUTO and NOCONFIRM have the same meaning as in
`revert-buffer'."
  (if (buffer-file-name)
      (when (or noconfirm
                (yes-or-no-p
                 (format (if (buffer-modified-p)
                             "Discard edits and reread from %s? "
                           "Revert buffer from file %s? ")
                         (buffer-file-name))))
        (let ((inhibit-read-only t))
          (funcall gpx-conversion-function)
          (run-hooks 'gpx-mode-postprocessing-functions)
          (set-buffer-modified-p nil)))
    (let ((revert-buffer-function nil))
      (revert-buffer ignore-auto noconfirm))))

(defun gpx-mode--revert-to-xml ()
  "Revert the current `gpx-mode' buffer to the original XML form."
  (when (and (buffer-file-name) (not (buffer-modified-p)))
    (let ((inhibit-read-only t))
      (erase-buffer)
      (goto-char (point-min))
      (insert-file-contents (buffer-file-name))
      (set-buffer-modified-p nil))))

(defun gpx-mode--imenu-create-index ()
  "Return an alist of (STRING . POS-IN-BUFFER) entries for `imenu'.
The returned alist contains positions of tracks in the GPX file."
  (goto-char (point-min))
  (append
   (when (looking-at "File: .*")
     (list (cons (match-string 0) (line-beginning-position))))
   (mapcar (pcase-lambda (`(,str ,marker ,_))
             (cons str (marker-position marker)))
           (gpx--collect-routes))))

(defvar gpx-mode-map
  (let ((map (copy-keymap button-buffer-map)))
    (set-keymap-parent map special-mode-map)
    (define-key map "\C-m" #'push-button)
    map)
  "Keymap used in `gpx-mode'.")

;;;###autoload
(define-derived-mode gpx-mode special-mode "GPX"
  "Major mode for viewing GPX files.
This mode uses \\='gpxinfo\\=' program to convert a GPX file in
XML form to human-readable form.  Alternatively, you can specify
your own conversion function via `gpx-conversion-function'.

Individual tracks/routes from the GPX file can be displayed by
clicking on the [Show map] button next to each track.  This will
use `gpx-show-map-function' to display that route.  By default,
the bundled \\='gpx2html.py\\=' script will be invoked that uses
Python \\='folium\\=' library to draw that route on an OSM map in
a HTML file.

For each track you can also see it's elevation profile by
clicking on the [Show elevation profile] button.  This uses
`gpx-generate-elevation-profile-function' to get the image for a
particular track.  By default, it will generate an image by
calling the bundled \\='plot_track_elevation.py\\=' Python
script.

\\{gpx-mode-map}"
  (setq-local font-lock-defaults '(gpx-mode-font-lock-keywords t))
  (setq-local imenu-create-index-function #'gpx-mode--imenu-create-index)
  (setq-local revert-buffer-function #'gpx-mode--revert-buffer)
  (setq buffer-undo-list t)

  (add-hook 'change-major-mode-hook #'gpx-mode--revert-to-xml nil t)

  (when buffer-file-name
    (revert-buffer nil (not (buffer-modified-p))))

  (read-only-mode 1)
  (button-mode +1))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.gpx\\'" . gpx-mode))


;; Other/workarounds

;;;###autoload
(defun gpx--file-handler (operation &rest args)
  "Call OPERATION with ARGS unless it is `write-region'.
A magic file name handler for GPX files that is only used to make
sure we never mess up any GPX file by overwriting it.  `gpx-mode'
should only used for browsing the files."
  (if (and (eq major-mode 'gpx-mode) (eq operation 'write-region))
      (error "Cannot save gpx-file")
    (let ((inhibit-file-name-handlers (cons 'gpx--file-handler
                                            inhibit-file-name-handlers))
          (inhibit-file-name-operation operation))
      (apply operation args))))

;;;###autoload
(add-to-list 'file-name-handler-alist '("\\.gpx\\'" . gpx--file-handler))

(provide 'gpx)
;;; gpx.el ends here

;; Local Variables:
;; indent-tabs-mode: nil
;; End:
