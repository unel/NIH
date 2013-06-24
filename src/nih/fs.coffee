class FS
    constructor: (size, cbS, cbE, cbF) ->
        window.storageInfo.requestQuota(window.PERSISTENT, size*1024*1024,
            (grantedBytes) =>
                # console.log('FS grantedBytes', grantedBytes)
                window.requestFileSystem(window.PERSISTENT, grantedBytes,
                    (fs) =>
                        console.log('FS initialized', grantedBytes, fs)
                        @fs = fs
                        A.UTILS.safeCall(cbS, @)
                        A.UTILS.safeCall(cbF, @)

                    (fe) =>
                        console.error('FS init error', fe)
                        A.UTILS.safeCall(cbE, fe)
                        A.UTILS.safeCall(cbF, @)
                )

            (fe) =>
                console.error('FS init error', fe)
                A.UTILS.safeCall(cbE, fe)
                A.UTILS.safeCall(cbF, @)
        )

    mkDir: (parent, dirName, cbS, cbE, cbF) ->
        parent.getDirectory(dirName, {"create": true},
            (dirEntry) =>
                # console.log("Dir entry created (or exists)", dirEntry)
                A.UTILS.safeCall(cbS, dirEntry)
                A.UTILS.safeCall(cbF, dirEntry)
            (fe) =>
                # console.log("Dir creating error", fe)
                A.UTILS.safeCall(cbE, fe)
                A.UTILS.safeCall(cbF, fe)
        )

    mkDirs: (parent, path, cbS, cbE, cbF) ->
        if !TYPES.isArray(path)
            path = path.split('/')
        if path[0] == '' || path[0] == '.'
            path = path.slice(1)

        dirName = path.shift()
        parent ?= @fs.root

        @mkDir(parent, dirName,
            (dirEntry) =>
                if path.length == 0
                    A.UTILS.safeCall(cbS, dirEntry)
                    A.UTILS.safeCall(cbF, dirEntry)
                else
                    @mkDirs(dirEntry, path, cbS, cbE, cbF)
            cbE, cbF
        )


    mkFile: (path, cbS, cbE, cbF) ->
        if !TYPES.isArray(path)
            path = path.split('/')
        if path[0] == '' || path[0] == '.'
            path = path.slice(1)

        fileName = path.pop()

        @mkDirs(undefined, path,
            (dirEntry) =>
                dirEntry.getFile(fileName, {"create": true, "exclusive": true},
                    (fileEntry) =>
                        # console.log("File created", fileEntry)
                        A.UTILS.safeCall(cbS, fileEntry)
                        A.UTILS.safeCall(cbF, fileEntry)
                    cbE, cbF
                )
            cbE, cbF)


    _rmFileFE: (fileEntry, cbS, cbE, cbF) ->
        fileEntry.remove(
            =>
                A.UTILS.safeCall(cbS)
                A.UTILS.safeCall(cbF)
            (fe) =>
                A.UTILS.safeCall(cbE, fe)
                A.UTILS.safeCall(cbF, fe)
        )

    _rmFileP: (path, cbS, cbE, cbF) ->
        @fs.root.getFile(path, {"create": false}
            (fileEntry) =>
                @_rmFileFE(fileEntry, cbS, cbE, cbF)

            (fe) =>
                A.UTILS.safeCall(cbE, fe)
                A.UTILS.safeCall(cbF, fe)
        )

    rmFile: (f, cbS, cbE, cbF) ->
        @[{
            "FileEntry": "_rmFileFE"
            "String": "_rmFileP"
        }[TYPES.type(f)]](f, cbS, cbE, cbF)



    open: (path, cbS, cbE, cbF) ->
        @fs.root.getFile(path, {"create": false},
            (fileEntry) =>
                A.UTILS.safeCall(cbS, fileEntry)
                A.UTILS.safeCall(cbF, fileEntry)
            (fe) ->
                A.UTILS.safeCall(cbE, fe)
                A.UTILS.safeCall(cbF, fe)
        )

    _writeFW: (fileWriter, opt, cbS, cbE, cbF) ->
        fileWriter.onwriteend = (e) =>
            A.UTILS.safeCall(cbS, e)
            A.UTILS.safeCall(cbF, e)

        fileWriter.onerror = (fe) =>
            A.UTILS.safeCall(cbE, fe)
            A.UTILS.safeCall(cbF, fe)


        if opt.position
            fileEnd = fileWriter.length
            pos = opt.position

            if TYPES.likeNumber(pos)
                if pos < 0
                    pos = fileEnd + pos
            else
                [label, delta] = pos.split(/[-+]/)
                positions = {
                    "end": fileEnd
                    "start": 0
                    "unknown": 0
                }
                pos = positions[label] ? positions.unknown
                if TYPES.likeNumber(delta)
                    pos += delta

            pos  = switch
                when pos < 0 then 0
                when pos > fileEnd then fileEnd
                else pos

            fileWriter.seek(pos)

        fileWriter.write(opt.data)

    _writeFE: (fileEntry, opt, cbS, cbE, cbF) ->
        writer = fileEntry.createWriter(
            (fileWriter) =>
                @_writeFW(fileWriter, opt, cbS, cbE, cbF)

            (fe) =>
                A.UTILS.safeCall(cbE, fe)
                A.UTILS.safeCall(cbF, fe)
        )

    _writeP: (path, opt, cbS, cbE, cbF) ->
        @open(path,
            (fileEntry) =>
                @_writeFE(fileWriter, opt, cbS, cbE, cbF)
            cbE, cbF
        )

    write: (to, opt, cbS, cbE, cbF) ->
        writeMethods = {
            "String": "_writeP"
            "FileEntry": "_writeFE"
            "FileWriter": "_writeFE"
        }

        writeMethod = writeMethods[TYPES.type(to)]
        return A.UTILS.safeCall(cbE, "incorrect object for write") unless writeMethod

        @[writeMethod](to, opt, cbS, cbE, cbF)




    _readF: (file, opt, cbS, cbE, cbF) ->
        reader = new FileReader()
        reader.onloadend = (e) ->
            safeCall(cbS, this.result, e)
            safeCall(cbF, this.result, e)

        reader.onerror = (fe) ->
            safeCall(cbE, fe)
            safeCall(cbF, fe)

        reader[opt.method || 'readAsText'](file) # readAs{Text,DataURL,ArrayBuffer}

    _readFE: (fileEntry, opt, cbS, cbE, cbF) ->
        fileEntry.file(
            (file) =>
                @_readF(file, opt, cbS, cbE, cbF)

            (fe) =>
                safeCall(cbE, fe)
                safeCall(cbF, fe)
        )

    _readP: (path, opt, cbS, cbE, cbF) ->
        @open(path,
            (fileEntry) =>
                @_readFE(fileEntry, opt, cbS, cbE, cbF)
            cbE, cbF
        )

    read: (from, opt, cbS, cbE, cbF) ->
        @[{
            "String": "_readP"
            "FileEntry": "_readFE"
            "File": "_readF"
        }[TYPES.type(from)]](from, opt, cbS, cbE, cbF)


    _dirDR: (dirReader, cbS, cbE, cbF) ->
        #

    _dirDE: (dirEntry, cbS, cbE, cbF) ->
        #

    _dirP: (path, cbS, cbE, cbF) ->
        #

    dir: (d, cbS, cbE, cbF) ->
        @[{
            "String": "_dirP"
            "DirectoryEntry": "_dirDE"
            "DirectoryReader": "_dirDR"
        }[TYPES.type(d)]](d, cbS, cbE, cbF)

window.FILES = FILES = {
    "FS": FS
}