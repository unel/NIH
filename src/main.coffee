# NIH.STORAGE.rqDo(
#     ['jquery', 'naked-ass']
#     ($, imageURL) ->

#         ancors = [
#             {
#                 "x":10, "y":10, "width":200, "height":70,
#                 "title": "ololo"
#             }
#         ]

#         map = $('<map>', {"name": "labelsmap"})
#         for anc in ancors
#             area = $('<area>', {
#                 "shape": "rect",
#                 "coords": "#{anc.x},#{anc.y},#{anc.x+anc.width},#{anc.y+anc.height}"
#                 "href": "javascript:alert('!')"
#             })
#             .css({
#                 "border": "1px solid red"
#             })
#             .appendTo(map)

#         map.appendTo('body')
#         img = $('<img>', {"src": imageURL, "usemap": "labelsmap"}).appendTo('body')

# )