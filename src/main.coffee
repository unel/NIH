storage = new A.RS.Storage("jquery"
    "scripts":
        "jquery":     ["/js/jquery-1.9.1.min.js", {"export": ["jQuery"]}],
        "jquery-ui":  ["/js/jquery-ui.js", {
            "export": ["jQuery"],
            "require": ["jquery:jQuery", "jquery-ui-stylesheet"]
        }],
        "underscore": ["/js/underscore.js", {"export": ["_"]}],

    "styles":
        "NIHCSS": "/src/NIH.css",
        "jquery-ui-stylesheet": "/css/jquery-ui-1.10.3.custom.css"

    "images":
        "naked-ass": "/img/nakedass.png",
        "heavy": "/img/33.jpg"
)

A.RS.rqDo(storage,
    ['jquery-ui', 'naked-ass']
    ($, imageURL) -> img = $("<div><img src='#{imageURL}'></div>").dialog({width: "auto"})
)

A.RS.rqDo(storage,
    ['naked-ass', 'jquery']
    (imageURL, $) -> $('<img>', {src: imageURL}).appendTo('body')
)