module.exports = (grunt) ->
    grunt.initConfig(
        pkg: grunt.file.readJSON("package.json")
        uglify:
            options:
                banner: '/*! <%= pkg.name %> <%= grunt.template.today("yyyy-mm-dd") %> */\n'
            build:
                src: 'src/<%= pkg.name %>.js'
                dest: 'build/<%= pkg.name %>.min.js'
        coffee:
            compile:
                expand: true
                flatten: true
                src: "src/*.coffee"
                dest: "build/"
                ext: ".js"
    )
    
    grunt.loadNpmTasks("grunt-contrib-uglify")
    grunt.loadNpmTasks('grunt-contrib-coffee');
    
    #grunt.registerTask("default", ["coffee", "uglify"])
    grunt.registerTask("default", ["coffee"])
    