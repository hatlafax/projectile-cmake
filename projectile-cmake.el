;;; projectile-cmake.el --- Minor mode for CMake projects based on projectile-mode

;; Copyright (C) 2020 Johannes Brunen (hatlafax)

;; Author:            Johannes Brunen <hatlafax@gmx.de>
;; URL:               -
;; Version:           0.1.0
;; Keywords:          cmake, projectile
;; Package-Requires:  ((emacs "27.1") (projectile "0.12.0") (cl-lib) (dash "2.17.0") (s "1.12.0") (f "0.20.0") (ivy 0.13.0) (counsel 0.13.0)(hydra "0.15.0"))

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; To start it for the cmake projects:
;;
;;    (projectile-cmake-global-mode)
;;
;;; Code:

(eval-when-compile (require 'cl-lib))
(require 'projectile)
(require 'dash)
(require 's)
(require 'f)
(require 'ivy)
(require 'hydra)
(require 'json)

(defgroup projectile-cmake nil
  "CMake mode based on projectile"
  :prefix "projectile-cmake-"
  :group 'projectile)


(defcustom projectile-cmake-root-file "CMakeLists.txt"
  "The file that is used to identify cmake root."
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-verify-root-files '("./CMakeLists.txt")
  "The list of files that is used to verify cmake root directory.
When any of the files are found it means that this is a cmake app."
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-executable "cmake"
  "The CMake executable."
  :group 'projectile-cmake
  :type 'string)

(defcustom projectile-emcmake-executable "emcmake"
  "The emcmake executable."
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-clang-c-executable "clang"
  "The clang C compiler executable."
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-clang-c++-executable "clang++"
  "The clang++, i.e. C++  compiler executable."
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-default-build-dir "../../Build"
  "The default CMake build directory
A relative path is starts at the respective project directory."
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-default-build-type "Release"
  "The default CMake build type.
The following build types are supported: Release, Debug, RelWithDebInfo and  MinSizeRel"
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-default-toolchain "gcc"
  "The default CMake toolchain.
The following toolchains are supported: gcc, clang, emcc and vs

gcc   : Gnu C/C++ compiler
clang : Clang C/C++ compiler
emcc  : Emscripten C/C++ to WASM/JS cross compiler
vs    : MS Visual Studio C++ compiler
"
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-default-architecture "x64"
  "The default CMake architecutre.
The following architecutres are supported: Win32, x64, ARM and ARM64
The architecture is only applied for the MS Visual Studio generators.
The other generators always target the x64 platform."
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-default-toolset "v120"
  "The default CMake toolset.
The following toolsets are supported:

  from Visual Studio  9 2008  : v80
                                v90 v90_xp
  from Visual Studio 10 2010  : v100 v100_xp
  from Visual Studio 11 2012  : v110 v110_xp
  from Visual Studio 12 2013  : v120 v120_xp
  from Visual Studio 14 2015  : v140 v140_clang v140_clang_c2 v140_xp
  from Visual Studio 15 2017  : v141 v141_clang v141_clang_c2 v141_xp
  from Visual Studio 16 2019  : v142 v142_clang v142_clang_c2 v142_xp

The toolset is only applied for the MS Visual Studio generators."
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-default-generator "MinGW Makefiles"
  "The default CMake generator.
The follwing generators are supported:
    Visual Studio 16 2019
    Visual Studio 15 2017
    Visual Studio 14 2015
    Visual Studio 12 2013
    Visual Studio 11 2012
    Visual Studio 10 2010
    Visual Studio 9 2008
    Borland Makefiles
    NMake Makefiles
    NMake Makefiles JOM
    MSYS Makefiles
    MinGW Makefiles
    Unix Makefiles
    Green Hills MULTI
    Ninja
    Ninja Multi-Config
    Watcom WMake
    CodeBlocks - MinGW Makefiles
    CodeBlocks - NMake Makefiles
    CodeBlocks - NMake Makefiles JOM
    CodeBlocks - Ninja
    CodeBlocks - Unix Makefiles
    CodeLite - MinGW Makefiles
    CodeLite - NMake Makefiles
    CodeLite - Ninja
    CodeLite - Unix Makefiles
    Sublime Text 2 - MinGW Makefiles
    Sublime Text 2 - NMake Makefiles
    Sublime Text 2 - Ninja
    Sublime Text 2 - Unix Makefiles
    Kate - MinGW Makefiles
    Kate - NMake Makefiles
    Kate - Ninja
    Kate - Unix Makefiles
    Eclipse CDT4 - NMake Makefiles
    Eclipse CDT4 - MinGW Makefiles
    Eclipse CDT4 - Ninja
    Eclipse CDT4 - Unix Makefiles

Attention: Not all generators allow to compile within Emacs.
"
  :group 'projectile-cmake
  :type 'string)


(defcustom projectile-cmake-default-run-in-build-dir t
  "Run project executable in build-dir.
If nil the executable defined by `projectile-cmake-project-run-cmd' is taken verbatim."
  :group 'projectile-cmake
  :type 'boolean)


(defcustom projectile-cmake-keymap-prefix nil
  "Keymap prefix for `projectile-cmake-mode'."
  :group 'projectile-cmake
  :type 'string)

(make-obsolete-variable
 'projectile-keymap-prefix
 "Use (define-key projectile-cnake-mode-map (kbd ...) 'projectile-cmake-command-map) instead." "0.1.0")

(defvar projectile-cmake-project-initialized nil
  "The project's build directory.")


(defvar projectile-cmake-project-build-dir nil
  "The project's build directory.")


(defvar projectile-cmake-project-build-type nil
  "The project's build type.")


(defvar projectile-cmake-project-generator nil
  "The project's CMake generator.")


(defvar projectile-cmake-project-architecture nil
  "The project's architecture.")


(defvar projectile-cmake-project-toolset nil
  "The project's toolset.")


(defvar projectile-cmake-project-toolchain nil
  "The project's toolchain.")


(defvar projectile-cmake-project-run-in-build-dir nil
  "Run project executable in build-dir.
If nil the executable defined by `projectile-cmake-project-run-cmd' is taken verbatim.")


(defvar projectile-cmake-project-run-generic-cmd nil
  "The project's debug run command.")


(defvar projectile-cmake-project-run-debug-cmd nil
  "The project's debug run command.")


(defvar projectile-cmake-project-run-release-cmd nil
  "The project's release run command.")


(defvar projectile-cmake-project-run-release-with-debug-info-cmd nil
  "The project's release with debug info run command.")


(defvar projectile-cmake-project-run-minimal-size-release-cmd nil
  "The project's minimal size release run command.")


(put 'projectile-cmake-project-initialized 'safe-local-variable #'booleanp)
(put 'projectile-cmake-project-build-dir 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-build-type 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-generator 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-architecture 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-toolset 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-toolchain 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-run-in-build-dir 'safe-local-variable #'booleanp)

(put 'projectile-cmake-project-run-generic-cmd 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-run-debug-cmd 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-run-release-cmd 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-run-release-with-debug-info-cmd 'safe-local-variable #'stringp)
(put 'projectile-cmake-project-run-minimal-size-release-cmd 'safe-local-variable #'stringp)

(put 'projectile-project-configure-cmd 'safe-local-variable #'stringp)
(put 'projectile-project-compilation-cmd 'safe-local-variable #'stringp)
(put 'projectile-project-install-cmd 'safe-local-variable #'stringp)
(put 'projectile-project-package-cmd 'safe-local-variable #'stringp)
(put 'projectile-project-test-cmd 'safe-local-variable #'stringp)
(put 'projectile-project-run-cmd 'safe-local-variable #'stringp)


(defvar projectile-cmake-cache-data
  (make-hash-table :test 'equal)
  "A hash table that is used for caching information about the current project.")


(defun projectile-cmake-cache-key (key)
  "Generate a cache key based on the current directory and the given KEY."
  (format "%s-%s" default-directory key))


(defun projectile-cmake--cmake-app-p (root)
  "Returns t if any of the relative files in `projectile-cmake-verify-root-files' is found.
ROOT is used to expand the relative files."
  (--any-p
   (file-exists-p (expand-file-name it root))
   (-list projectile-cmake-verify-root-files)))

(defun projectile-cmake-valid-p ()
    "Return t if called from a valid projectile cmake context."
    (and
         (projectile-project-p) ;; detect if current buffer is in a project
         (or
          (derived-mode-p 'cmake-mode)
          (derived-mode-p 'c-mode)
          (derived-mode-p 'c++-mode)
          )))


(defun projectile-cmake--ignore-buffer-p ()
  "Return t if `projectile-cmake' should not be enabled for the current buffer."
  (string-match-p "\\*\\(Minibuf-[0-9]+\\|helm mini\\|helm projectile\\)\\*" (buffer-name)))


(defun projectile-cmake-root ()
  "Return cmake root directory if this file is a part of a CMake application else nil."
  (let* ((cache-key (projectile-cmake-cache-key "root"))
         (cache-value (gethash cache-key projectile-cmake-cache-data)))
    (or cache-value
        (ignore-errors
          (let ((root (projectile-locate-dominating-file default-directory projectile-cmake-root-file)))
            (when (projectile-cmake--cmake-app-p root)
              (puthash cache-key root projectile-cmake-cache-data)
              root))))))


(defun projectile-cmake-apply-ansi-color ()
  (ansi-color-apply-on-region compilation-filter-start (point)))


(defun projectile-cmake-dir-locals-reload-for-current-buffer ()
  "Reload dir locals for the current buffer."
  (let ((enable-local-variables :all))
    (hack-dir-local-variables-non-file-buffer)))


(defun projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory ()
  "For every buffer with the same `default-directory` as the current buffer's, reload dir-locals."
  (let ((dir default-directory))
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (equal default-directory dir))
        (projectile-cmake-dir-locals-reload-for-current-buffer)))))


(defun projectile-cmake-select-from-item-list (prompt given-list &optional index)
    "Select item from list GIVEN-LIST.
This function simply delegates to ivy-read."
    (if (= 1 (length given-list))
        (car given-list)
        (ivy-read prompt given-list :require-match t :preselect index)))


(defun projectile-cmake-choose-directory (directory-to-start-in)
  "Return a directory chosen by the user.
The user will be prompted to choose a directory starting with `directory-to-start-in'"
  (let* ((ivy-read-prompt "Choose directory: ")
         (counsel--find-file-predicate #'file-directory-p)
         (default-directory directory-to-start-in)
         (selected-directory
          (ivy-read
           ivy-read-prompt
           #'read-file-name-internal
           :matcher #'counsel--find-file-matcher)))
    selected-directory))


(defun projectile-cmake-find-file (directory-to-start-in)
  "Return a file choosen by the user.
The user will be prompted to choose a executable file starting with `directory-to-start-in'"
  (expand-file-name (read-file-name "Enter file name: " directory-to-start-in)))


(defun projectile-cmake-read-json-file ()
    "Read and evaluate a '.projectile-cmake' file in the project root directory.

The file .projectile-cmake is expected to be written in valid JSON format.

The following keys are evaluated:
    \"configure-flags\" : all flags listed in the array value associated to this key are
                          concatenated and then added to the configure command line.

Example:
    {
        \"configure-flags\": [
            \"-D test1\",
            \"-D test2\",
            \"-D test3 -D test4\",
            \"--target test5\"
        ]
    }
"
    (let ((configure-flags ""))
        (when (projectile-project-p)
            (projectile-with-default-dir
                (if (projectile-project-p)
                    (projectile-project-root) default-directory)

                (let* ((file (concat (projectile-project-root) ".projectile-cmake")))
                    (when (file-exists-p file)
                        (let* ( (json-object-type 'hash-table)
                                (json-array-type 'list)
                                (json-key-type 'string)
                                (json (json-read-file file))
                                (flags (gethash "configure-flags" json))
                              )
                          (dolist (flag flags)
                            (setq configure-flags (concat configure-flags " " flag)))

                          (s-trim configure-flags)
                        )
                    )
                )
            )
        )
        (list configure-flags)
    )
)
;;
;; Semantic implementation
;;

;; projectile-cmake--get-xxx
(defun projectile-cmake--get-build-dir ()
  "Get build directory from .dir-locals.el file."
  (projectile-with-default-dir
      (if (projectile-project-p)
          (projectile-project-root) default-directory)
    (when (eq  projectile-cmake-project-build-dir nil)
      (if (f-relative? projectile-cmake-default-build-dir)
          (projectile-cmake--set-build-dir (f-full
                                            (f-join (projectile-project-root)
                                                    projectile-cmake-default-build-dir
                                                    (projectile-project-name))))
        (projectile-cmake--set-build-dir (f-full (f-join projectile-cmake-default-build-dir (projectile-project-name))))
        ))
    projectile-cmake-project-build-dir))

(defun projectile-cmake--get-build-type ()
  "Get build type from .dir-locals.el file."
  (when (eq  projectile-cmake-project-build-type nil)
    (projectile-cmake--set-build-type projectile-cmake-default-build-type))
  projectile-cmake-project-build-type)


(defun projectile-cmake--get-generator ()
  "Get generator from .dir-locals.el file."
  (when (eq  projectile-cmake-project-generator nil)
    (projectile-cmake--set-generator projectile-cmake-default-generator))
  projectile-cmake-project-generator)


(defun projectile-cmake--get-architecture ()
  "Get architecture from .dir-locals.el file."
  (when (eq  projectile-cmake-project-architecture nil)
    (projectile-cmake--set-architecture projectile-cmake-default-architecture))
  projectile-cmake-project-architecture)


(defun projectile-cmake--get-toolset ()
  "Get toolset from .dir-locals.el file."
  (when (eq  projectile-cmake-project-toolset nil)
    (projectile-cmake--set-toolset projectile-cmake-default-toolset))
  projectile-cmake-project-toolset)


(defun projectile-cmake--get-toolchain ()
  "Get toolchain from .dir-locals.el file."
  (when (eq  projectile-cmake-project-toolchain nil)
    (projectile-cmake--set-toolchain projectile-cmake-default-toolchain))
  projectile-cmake-project-toolchain)


(defun projectile-cmake--get-run-in-build-dir ()
  "Get run in build directory flag from .dir-locals.el file."
  (when (eq  projectile-cmake-project-run-in-build-dir nil)
    (projectile-cmake--set-run-in-build-dir projectile-cmake-default-run-in-build-dir))
  projectile-cmake-project-run-in-build-dir)


(defun projectile-cmake--get-configure-cmd()
  "Get configure command from .dir-locals.el file."
  (when (eq  projectile-project-configure-cmd nil)
    (projectile-cmake--set-configure-cmd))
  projectile-project-configure-cmd)


(defun projectile-cmake--get-compilation-cmd()
  "Get compilation command from .dir-locals.el file."
  (when (eq  projectile-project-compilation-cmd nil)
    (projectile-cmake--set-compilation-cmd))
  projectile-project-compilation-cmd)


(defun projectile-cmake--get-install-cmd()
  "Get install command from .dir-locals.el file."
  (when (eq  projectile-project-install-cmd nil)
    (projectile-cmake--set-install-cmd))
  projectile-project-install-cmd)


(defun projectile-cmake--get-package-cmd()
  "Get package command from .dir-locals.el file."
  (when (eq  projectile-project-package-cmd nil)
    (projectile-cmake--set-package-cmd))
  projectile-project-package-cmd)


(defun projectile-cmake--get-test-cmd()
  "Get test command from .dir-locals.el file."
  (when (eq  projectile-project-test-cmd nil)
    (projectile-cmake--set-test-cmd))
  projectile-project-test-cmd)


(defun projectile-cmake--get-run-generic-cmd()
  "Get generic run command from .dir-locals.el file."
  projectile-cmake-project-run-generic-cmd)

(defun projectile-cmake--get-run-debug-cmd()
  "Get debug run command from .dir-locals.el file."
  projectile-cmake-project-run-debug-cmd)

(defun projectile-cmake--get-run-release-cmd()
  "Get release run command from .dir-locals.el file."
  projectile-cmake-project-run-release-cmd)

(defun projectile-cmake--get-run-release-with-debug-info-cmd()
  "Get release with debug info run command from .dir-locals.el file."
  projectile-cmake-project-run-release-with-debug-info-cmd)

(defun projectile-cmake--get-run-minimal-size-release-cmd()
  "Get minimal size release run command from .dir-locals.el file."
  projectile-cmake-project-run-minimal-size-release-cmd)


;; projectile-cmake--set-xxx
(defun projectile-cmake--set-build-dir (value &optional evaluate)
  "Add build directory variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-build-dir value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-build-type (value &optional evaluate)
  "Add build type variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-build-type value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-generator (value &optional evaluate)
  "Add generator variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-generator value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-architecture (value &optional evaluate)
  "Add architecture variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-architecture value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-toolset (value &optional evaluate)
  "Add toolset variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-toolset value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-toolchain(value &optional evaluate)
  "Add toolchain variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-toolchain value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-run-in-build-dir(value &optional evaluate)
  "Add run in build directory flag variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-run-in-build-dir value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-configure-cmd(&optional evaluate)
  "Add configure command variable to .dir-locals.el file."
  (projectile-with-default-dir
      (if (projectile-project-p)
          (projectile-project-root) default-directory)

    (let (( value )
          (default-directory (projectile-cmake-project-build-dir))
          (toolchain (projectile-cmake--get-toolchain))
          (emcmake-exe projectile-emcmake-executable)
          (cmake-exe projectile-cmake-executable)
          (generator (prin1-to-string (projectile-cmake--get-generator)))
          (build-type (projectile-cmake--get-build-type))
          (architecture (projectile-cmake--get-architecture))
          (toolset (projectile-cmake--get-toolset))
          (root (f-full (projectile-project-root)))
          (json (projectile-cmake-read-json-file))
          )
      (when (equal toolchain "clang")
        (setq value (concat cmake-exe
                            " -G " generator
                            " -DCMAKE_BUILD_TYPE=" build-type
                            " -DCMAKE_C_COMPILER=" projectile-cmake-clang-c-executable
                            " -DCMAKE_CXX_COMPILER=" projectile-cmake-clang-c++-executable
                            (nth 0 json)
                            " -B " default-directory
                            " -S " root
                            )))

      (when (equal toolchain "gcc")
        (setq value (concat cmake-exe
                            " -G " generator
                            " -DCMAKE_BUILD_TYPE=" build-type
                            (nth 0 json)
                            " -B " default-directory
                            " -S " root
                        )))

    ;;
    ;; ToDo emcc
    ;;
      (when (equal toolchain "emcc")
        (setq value (concat emcmake-exe " "
                            cmake-exe
                            " -G " generator
                            " -DCMAKE_BUILD_TYPE=" build-type
                            (nth 0 json)
                            " -B " default-directory
                            " -S " root
                            )))

      (when (equal toolchain "vs")
        (setq value (concat cmake-exe
                            " -G " generator
                            " -A " architecture
                            " -T " toolset
                            (nth 0 json)
                            " -B " default-directory
                            " -S " root
                        )))

      (save-current-buffer
          (add-dir-local-variable nil 'projectile-project-configure-cmd value)

          (when projectile-configure-cmd-map
            (puthash default-directory value projectile-configure-cmd-map))

          (unless evaluate
            (save-buffer)
            (kill-buffer)
            (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))))


(defun projectile-cmake--set-compilation-cmd(&optional evaluate)
  "Add compilation command variable to .dir-locals.el file."
  (projectile-with-default-dir
      (if (projectile-project-p)
          (projectile-project-root) default-directory)

    (let (( value )
          (default-directory (projectile-cmake-project-build-dir))
          (toolchain (projectile-cmake--get-toolchain))
          (cmake-exe projectile-cmake-executable)
          (build-type (projectile-cmake--get-build-type))
          )
      (when (equal toolchain "clang")
        (setq value (concat cmake-exe
                            " --build " default-directory
                            )))

      (when (equal toolchain "gcc")
        (setq value (concat cmake-exe
                            " --build " default-directory
                            )))

      (when (equal toolchain "emcc")
        (setq value (concat cmake-exe
                            " --build " default-directory
                            )))

      (when (equal toolchain "vs")
        (setq value (concat cmake-exe
                            " --build  " default-directory
                            " --config " build-type
                            )))

      (save-current-buffer
          (add-dir-local-variable nil 'projectile-project-compilation-cmd value)

          (when projectile-compilation-cmd-map
            (puthash default-directory value projectile-compilation-cmd-map))

          (unless evaluate
            (save-buffer)
            (kill-buffer)
            (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))))


(defun projectile-cmake--set-install-cmd(&optional evaluate)
  "Add install command variable to .dir-locals.el file."
  (projectile-with-default-dir
      (if (projectile-project-p)
          (projectile-project-root) default-directory)

    (let (( value )
          (default-directory (projectile-cmake-project-build-dir))
          (toolchain (projectile-cmake--get-toolchain))
          (cmake-exe projectile-cmake-executable)
          (build-type (projectile-cmake--get-build-type))
          )
      (when (equal toolchain "clang")
        (setq value (concat cmake-exe
                            " --build " default-directory
                            " --target install"
                            )))

      (when (equal toolchain "gcc")
        (setq value (concat cmake-exe
                            " --build " default-directory
                            " --target install"
                            )))

      (when (equal toolchain "emcc")
        (setq value (concat cmake-exe
                            " --build " default-directory
                            " --target install"
                            )))

      (when (equal toolchain "vs")
        (setq value (concat cmake-exe
                            " --build  " default-directory
                            " --config " build-type
                            " --target install"
                            )))

      (save-current-buffer
            (add-dir-local-variable nil 'projectile-project-install-cmd value)

          (when projectile-install-cmd-map
            (puthash default-directory value projectile-install-cmd-map))

          (unless evaluate
            (save-buffer)
            (kill-buffer)
            (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))))


(defun projectile-cmake--set-package-cmd(&optional evaluate)
  "Add package command variable to .dir-locals.el file."
  (projectile-with-default-dir
      (if (projectile-project-p)
          (projectile-project-root) default-directory)

    (let (( value )
          (default-directory (projectile-cmake-project-build-dir))
          (toolchain (projectile-cmake--get-toolchain))
          (cmake-exe projectile-cmake-executable)
          (build-type (projectile-cmake--get-build-type))
          )
      (when (equal toolchain "clang")
        (setq value (concat cmake-exe
                            " --build " default-directory
                            " --target package"
                            )))

      (when (equal toolchain "gcc")
        (setq value (concat cmake-exe
                            " --build " default-directory
                            " --target package"
                            )))

      (when (equal toolchain "emcc")
        (setq value (concat cmake-exe
                            " --build " default-directory
                            " --target package"
                            )))

      (when (equal toolchain "vs")
        (setq value (concat cmake-exe
                            " --build  " default-directory
                            " --config " build-type
                            " --target package"
                            )))

      (save-current-buffer
          (add-dir-local-variable nil 'projectile-project-package-cmd value)

          (when projectile-package-cmd-map
            (puthash default-directory value projectile-package-cmd-map))

          (unless evaluate
            (save-buffer)
            (kill-buffer)
            (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))))

;; ToDo...
(defun projectile-cmake--set-test-cmd(&optional evaluate)
  "Add test command variable to .dir-locals.el file."
  (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory)))


(defun projectile-cmake--set-run-cmd(&optional evaluate)
  "Add run command variable to .dir-locals.el file."
  (when (projectile-cmake-valid-p)
    (let ((run-exe                         (projectile-cmake--get-run-generic-cmd))
          (run-debug-exe                   (projectile-cmake--get-run-debug-cmd))
          (run-release-exe                 (projectile-cmake--get-run-release-cmd))
          (run-release-with-debug-info-exe (projectile-cmake--get-run-release-with-debug-info-cmd))
          (run-minimal-size-release-exe    (projectile-cmake--get-run-minimal-size-release-cmd))
          (build-type                      (projectile-cmake--get-build-type))
          (run-in-build-dir                (projectile-cmake--get-run-in-build-dir))
          (build-dir                       (projectile-cmake-project-build-dir)))

      (when (and run-in-build-dir (not (eq run-exe nil)) (f-file? run-exe))
        (setq run-exe (f-join build-dir (f-filename run-exe))))

      (when (and (not (eq run-debug-exe nil))
                 (equal build-type "Debug")
                 (f-file? run-debug-exe))
        (when run-in-build-dir
          (setq run-debug-exe (f-join build-dir (f-filename run-debug-exe))))
        (when (f-exists? run-debug-exe)
          (setq run-exe run-debug-exe)))

      (when (and (not (eq run-release-exe nil))
                 (equal build-type "Release")
                 (f-file? run-release-exe))
        (when run-in-build-dir
          (setq run-release-exe (f-join build-dir (f-filename run-release-exe))))
        (when (f-exists? run-release-exe)
          (setq run-exe run-release-exe)))

      (when (and (not (eq run-release-with-debug-info-exe nil))
                 (equal build-type "RelWithDebInfo")
                 (f-file? run-release-with-debug-info-exe))
        (when run-in-build-dir
          (setq run-release-with-debug-info-exe (f-join build-dir (f-filename run-release-with-debug-info-exe))))
        (when (f-exists? run-release-with-debug-info-exe)
          (setq run-exe run-release-with-debug-info-exe)))

      (when (and (not (eq run-minimal-size-release-exe nil))
                 (equal build-type "MinSizeRel")
                 (f-file? run-minimal-size-release-exe))
        (when run-in-build-dir
          (setq run-minimal-size-release-exe (f-join build-dir (f-filename run-minimal-size-release-exe))))
        (when (f-exists? run-minimal-size-release-exe)
          (setq run-exe run-minimal-size-release-exe)))

      (unless (eq run-exe nil)
        (unless (f-exists? run-exe)
          (setq run-exe nil)))

      (unless (eq run-exe nil)
        (save-current-buffer
          (add-dir-local-variable nil 'projectile-project-run-cmd run-exe)

          (unless evaluate
              (save-buffer)
              (kill-buffer)
              (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))
    )))


(defun projectile-cmake--set-run-generic-cmd(value &optional evaluate)
  "Add generic run command variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-run-generic-cmd value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-run-debug-cmd(value &optional evaluate)
  "Add debug run command variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-run-debug-cmd value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-run-release-cmd(value &optional evaluate)
  "Add release run command variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-run-release-cmd value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-run-release-with-debug-info-cmd(value &optional evaluate)
  "Add release with debug info run command variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-run-release-with-debug-info-cmd value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-run-minimal-size-release-cmd(value &optional evaluate)
  "Add minimal size release run command variable to .dir-locals.el file."
  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-run-minimal-size-release-cmd value)
    (unless evaluate
        (save-buffer)
        (kill-buffer)
        (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))


(defun projectile-cmake--set-all-commands(&optional evaluate)
  "Add all CMake command variables to .dir-locales.el file."
  (projectile-cmake--set-configure-cmd t)
  (projectile-cmake--set-compilation-cmd t)
  (projectile-cmake--set-install-cmd t)
  (projectile-cmake--set-package-cmd t)
  (projectile-cmake--set-test-cmd t)
  (projectile-cmake--set-run-cmd t)

  (save-current-buffer
    (add-dir-local-variable nil 'projectile-cmake-project-initialized t)

    (unless evaluate
      (save-buffer)
      (kill-buffer)
      (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))

(defun projectile-cmake-initialize ()
  "Initializes the .dir-locals.el variables."
  (interactive)
  (when (and
         (projectile-project-p) ;; detect if current buffer is in a project
         (or
          (derived-mode-p 'cmake-mode)
          (derived-mode-p 'c-mode)
          (derived-mode-p 'c++-mode)
          ) ; or
         (eq projectile-cmake-project-initialized nil)
         ) ; and
    (let ((_))
      (setq _ (projectile-cmake--get-build-dir))
      (setq _ (projectile-cmake--get-build-type))
      (setq _ (projectile-cmake--get-architecture))
      (setq _ (projectile-cmake--get-generator))
      (setq _ (projectile-cmake--get-toolset))
      (setq _ (projectile-cmake--get-toolchain))
      (setq _ (projectile-cmake--get-run-in-build-dir))

      (projectile-cmake--set-all-commands t)

      (add-dir-local-variable nil 'projectile-cmake-project-initialized t)

      (save-buffer)
      (kill-buffer)
      (projectile-cmake-dir-locals-reload-for-all-buffer-in-this-directory))))

(defun projectile-cmake-reinitialize ()
  "Reinitializes an already initialized project.
Normally, this is not necessary. In cases that for instance an '.projectile-cmake'
JSON file was added or modified, running this command is necessary."
  (interactive)
  (when (and
         (projectile-project-p) ;; detect if current buffer is in a project
         (or
          (derived-mode-p 'cmake-mode)
          (derived-mode-p 'c-mode)
          (derived-mode-p 'c++-mode)
          ) ; or
         ) ; and
    (setq projectile-cmake-project-initialized nil)
    (projectile-cmake-initialize)
    ;(add-dir-local-variable nil 'projectile-cmake-project-initialized nil)
  )
)


;;
;; Interactive
;;

(defun projectile-cmake-project-build-dir ()
  "The project build directory."
  (interactive)
  (let (( value (projectile-cmake--get-build-dir) ))
    (when (equal (projectile-cmake--get-toolchain) "clang")
      (setq value (f-join value (projectile-cmake--get-toolchain) (projectile-cmake--get-build-type))))

    (when (equal (projectile-cmake--get-toolchain) "gcc")
      (setq value (f-join value (projectile-cmake--get-toolchain) (projectile-cmake--get-build-type))))

    (when (equal (projectile-cmake--get-toolchain) "emcc")
      (setq value (f-join value (projectile-cmake--get-toolchain) (projectile-cmake--get-build-type))))

    (when (equal (projectile-cmake--get-toolchain) "vs")
      (setq value (f-join value (projectile-cmake--get-toolchain))))

    value))

(advice-add 'projectile-compilation-dir :filter-return #'projectile-cmake-compilation-dir)
(defun projectile-cmake-compilation-dir (directory)
  "Filter the projectile compilation dir and replace it with our build dir."
  (let (( result directory))
    (when (projectile-cmake-valid-p)
      (setq result (projectile-cmake-project-build-dir))

      (unless (f-exists? result)
        (apply 'f-mkdir (f-split result)))

      )
    result))

(defun projectile-cmake-select-build-dir ()
  "Select the current project build dir.
Remark: Configuration automatically does take place in a project specific sub directory.
"
  (interactive)
  (when (projectile-cmake-valid-p)
    (let* (( result (projectile-cmake-choose-directory (projectile-cmake--get-build-dir)) ))
      (unless (f-exists? result)
        (apply 'f-mkdir (f-split result)))
      (if (equal (f-filename result) (projectile-project-name))
          (projectile-cmake--set-build-dir result)
        (projectile-cmake--set-build-dir (f-full (f-join result (projectile-project-name)))))
      (projectile-cmake--set-all-commands))))


(defun projectile-cmake-select-build-type ()
  "Select the current project build type"
  (interactive)
  (when (projectile-cmake-valid-p)
    (let* (( result (projectile-cmake-select-from-item-list
                     "Build type: "
                     '(
                       "Debug"
                       "Release"
                       "RelWithDebInfo"
                       "MinSizeRel")
                     (projectile-cmake--get-build-type))))
      (projectile-cmake--set-build-type result)
      (projectile-cmake--set-all-commands))))


(defun projectile-cmake-select-generator ()
  "Select the current project ; commentnfiguration generator"
  (interactive)
  (when (projectile-cmake-valid-p)
    (let* (( result (projectile-cmake-select-from-item-list
                     "Generator: "
                     '(
                       "Visual Studio 16 2019"
                       "Visual Studio 15 2017"
                       "Visual Studio 14 2015"
                       "Visual Studio 12 2013"
                       "Visual Studio 11 2012"
                       "Visual Studio 10 2010"
                       "Visual Studio 9 2008"
                       "Borland Makefiles"
                       "NMake Makefiles"
                       "NMake Makefiles JOM"
                       "MSYS Makefiles"
                       "MinGW Makefiles"
                       "Unix Makefiles"
                       "Green Hills MULTI"
                       "Ninja"
                       "Ninja Multi-Config"
                       "Watcom WMake"
                       "CodeBlocks - MinGW Makefiles"
                       "CodeBlocks - NMake Makefiles"
                       "CodeBlocks - NMake Makefiles JOM"
                       "CodeBlocks - Ninja"
                       "CodeBlocks - Unix Makefiles"
                       "CodeLite - MinGW Makefiles"
                       "CodeLite - NMake Makefiles"
                       "CodeLite - Ninja"
                       "CodeLite - Unix Makefiles"
                       "Sublime Text 2 - MinGW Makefiles"
                       "Sublime Text 2 - NMake Makefiles"
                       "Sublime Text 2 - Ninja"
                       "Sublime Text 2 - Unix Makefiles"
                       "Kate - MinGW Makefiles"
                       "Kate - NMake Makefiles"
                       "Kate - Ninja"
                       "Kate - Unix Makefiles"
                       "Eclipse CDT4 - NMake Makefiles"
                       "Eclipse CDT4 - MinGW Makefiles"
                       "Eclipse CDT4 - Ninja"
                       "Eclipse CDT4 - Unix Makefiles"
                       )
                     (projectile-cmake--get-generator))))

      (when (and (s-starts-with? "Visual Studio" result) (not (equal (projectile-cmake--get-toolchain) "vs")))
        (projectile-cmake--set-toolchain "vs"))

      (when (and (--any? (s-starts-with? it result)
                         '("MSYS" "MinGW" "Unix" "Ninja"))
                 (equal (projectile-cmake--get-toolchain) "vs")
                 (projectile-cmake--set-toolchain "gcc")))

      (projectile-cmake--set-generator result)
      (projectile-cmake--set-all-commands))))

(defun projectile-cmake-select-architecture ()
  "Select the current project configuration architecture"
  (interactive)
  (when (projectile-cmake-valid-p)
    (let* (( result (projectile-cmake-select-from-item-list
                     "Architecture: "
                     '(
                       "Win32"
                       "x64"
                       "ARM"
                       "ARM64"
                       )
                     (projectile-cmake--get-architecture))))
      (projectile-cmake--set-architecture result)
      (projectile-cmake--set-all-commands))))


(defun projectile-cmake-select-toolset ()
  "Select the current project configuration toolset.
The toolset feature is used only for Visual Studio generators."
  (interactive)
  (when (projectile-cmake-valid-p)
    (let* (( result (projectile-cmake-select-from-item-list
                     "Toolset: "
                     '(
                       "v80"
                       "v90" "v90_xp"
                       "v100" "v100_xp"
                       "v110" "v110_xp"
                       "v120" "v120_xp"
                       "v140" "v140_clang" "v140_clang_c2" "v140_xp"
                       "v141" "v141_clang" "v141_clang_c2" "v141_xp"
                       "v142" "v142_clang" "v142_clang_c2" "v142_xp"
                       )
                     (projectile-cmake--get-toolset))))
      (projectile-cmake--set-toolset result)
      (projectile-cmake--set-all-commands))))


(defun projectile-cmake-select-toolchain ()
  "Select the current project configuration toolchain"
  (interactive)
  (when (projectile-cmake-valid-p)
    (let* (( result (projectile-cmake-select-from-item-list
                     "Toolchain: "
                     '(
                       "gcc"
                       "clang"
                       "emcc"
                       "vs"
                       )
                     (projectile-cmake--get-toolchain))))
      (projectile-cmake--set-toolchain result)
      (projectile-cmake--set-all-commands))))


(defun projectile-cmake-select-run-file ()
    "Select the file that should be run for the project."
    (interactive)
    (when (projectile-cmake-valid-p)
      (let* (( result (projectile-cmake-find-file (projectile-cmake-project-build-dir)) ))
        (projectile-cmake--set-run-generic-cmd result t)
        (projectile-cmake--set-run-cmd))))


(defun projectile-cmake-select-run-file-debug ()
    "Select the file that should be run for the debug project."
    (interactive)
    (when (projectile-cmake-valid-p)
      (let* (( result (projectile-cmake-find-file (projectile-cmake-project-build-dir)) ))
        (projectile-cmake--set-run-debug-cmd result t)
        (projectile-cmake--set-run-cmd))))


(defun projectile-cmake-select-run-file-release ()
    "Select the file that should be run for the release project."
    (interactive)
    (when (projectile-cmake-valid-p)
      (let* (( result (projectile-cmake-find-file (projectile-cmake-project-build-dir)) ))
        (projectile-cmake--set-run-release-cmd result t)
        (projectile-cmake--set-run-cmd))))


(defun projectile-cmake-select-run-file-release-with-debug-info ()
    "Select the file that should be run for the release with debug info project."
    (interactive)
    (when (projectile-cmake-valid-p)
      (let* (( result (projectile-cmake-find-file (projectile-cmake-project-build-dir)) ))
        (projectile-cmake--set-run-release-with-debug-info-cmd result t)
        (projectile-cmake--set-run-cmd))))


(defun projectile-cmake-select-run-file-minimal-size-release ()
    "Select the file that should be run for the minimal size release project."
    (interactive)
    (when (projectile-cmake-valid-p)
      (let* (( result (projectile-cmake-find-file (projectile-cmake-project-build-dir)) ))
        (projectile-cmake--set-run-minimal-size-release-cmd result t)
        (projectile-cmake--set-run-cmd))))


(defun projectile-cmake-toggle-run-in-build-dir ()
  "Toggle the run in build directory flag variable.
If this variable is nil the run executable path is taken verbatim."
  (interactive)
  (when (projectile-cmake-valid-p)
    (let ((flag (projectile-cmake--get-run-in-build-dir)))
      (setq flag (not flag))
      (projectile-cmake--set-run-in-build-dir flag)
      (projectile-cmake--set-run-cmd)
      )))

;;
;; --
;;

(defvar projectile-cmake-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "s d") #'projectile-cmake-select-build-dir)
    (define-key map (kbd "s t") #'projectile-cmake-select-build-type)
    (define-key map (kbd "s g") #'projectile-cmake-select-generator)
    (define-key map (kbd "s a") #'projectile-cmake-select-architecture)
    (define-key map (kbd "s s") #'projectile-cmake-select-toolset)
    (define-key map (kbd "s c") #'projectile-cmake-select-toolchain)
    (define-key map (kbd "s r g") #'projectile-cmake-select-run-file)
    (define-key map (kbd "s r d") #'projectile-cmake-select-run-file-debug)
    (define-key map (kbd "s r r") #'projectile-cmake-select-run-file-release)
    (define-key map (kbd "s r i") #'projectile-cmake-select-run-file-release-with-debug-info)
    (define-key map (kbd "s r m") #'projectile-cmake-select-run-file-minimal-size-release)
    (define-key map (kbd "t d") #'projectile-cmake-toggle-run-in-build-dir)
    (define-key map (kbd "e r") #'projectile-cmake-reinitialize)

    map)
  "Keymap after `projectile-cmake-keymap-prefix'.")
(fset 'projectile-cmake-command-map projectile-cmake-command-map)


(defvar projectile-cmake-mode-map
  (let ((map (make-sparse-keymap)))
    (when projectile-cmake-keymap-prefix
      (define-key map projectile-cmake-keymap-prefix 'projectile-cmake-command-map))
    map)
  "Keymap for `projectile-cmake-mode'.")


;;;###autoload
(define-minor-mode projectile-cmake-mode
  "CMake mode based on projectile"
  :init-value nil
  :lighter " CM"
)


;;;###autoload
(defun projectile-cmake-on ()
  "Enable `projectile-cmake-mode' minor mode if this is a cmake project."
  (when (and
         (not (projectile-cmake--ignore-buffer-p))
         (projectile-project-p)
         (projectile-cmake-root))
    (projectile-cmake-mode +1)))


;;;###autoload
(define-globalized-minor-mode projectile-cmake-global-mode
  projectile-cmake-mode
  projectile-cmake-on)

(add-hook 'projectile-find-file-hook      #'projectile-cmake-initialize)
(add-hook 'projectile-switch-project-hook #'projectile-cmake-initialize)

(defun projectile-cmake-off ()
  "Disable `projectile-cmake-mode' minor mode."
  (projectile-cmake-mode -1))


(define-derived-mode projectile-cmake-compilation-mode compilation-mode "Projectile CMake Compilation"
  "Compilation mode used by `projectile-cmake'."
  (add-hook 'compilation-filter-hook 'projectile-cmake-apply-ansi-color nil t)
  (projectile-cmake-mode +1))

(with-no-warnings
  (ignore-errors
    (defhydra hydra-projectile-cmake
      (:color pink :hint nil)
"
^^^^Projectile CMake
^^^^--------------------------------------------------------------------------------
_sd_: select build directory         | _srg_: select run file
_st_: select build type              | _srd_: select run file debug
_sg_: select generator               | _srr_: select run file release
_sa_: select architecture            | _sri_: select run file release with debug
_ss_: select toolset                 | _srm_: select run file release minimal size
_sc_: select toolchain               |
^^-----------------------------------+^^--------------------------------------------
_td_: toggle: Run in build directory | _q_: quit
_er_; reinitialize
"
    ("sd" projectile-cmake-select-build-dir)
    ("st" projectile-cmake-select-build-type)
    ("sg" projectile-cmake-select-generator)
    ("sa" projectile-cmake-select-architecture)
    ("ss" projectile-cmake-select-toolset)
    ("sc" projectile-cmake-select-toolchain)
    ("srg" projectile-cmake-select-run-file)
    ("srd" projectile-cmake-select-run-file-debug)
    ("srr" projectile-cmake-select-run-file-release)
    ("sri" projectile-cmake-select-run-file-release-with-debug-info)
    ("srm" projectile-cmake-select-run-file-minimal-size-release)
    ("td" projectile-cmake-toggle-run-in-build-dir)
    ("er" projectile-cmake-reinitialize)
    ("q" nil :color blue)
    )))

(provide 'projectile-cmake)
