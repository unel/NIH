# return

storage = new A.RS.Storage("jquery", "/rs/test_repo.json");


A.RS.rqDo(storage,
    ['jquery-ui-c', 'heavy-c']
    ($, imageURL) -> $("<div><img src='#{imageURL}'></div>").dialog({width: "auto"})
)

# A.RS.rqDo(storage,
#     ['naked-ass', 'jquery']
#     (imageURL, $) -> $('<img>', {src: imageURL}).appendTo('body')
# )