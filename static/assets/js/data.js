var exampleSocket = new WebSocket("ws://localhost:8080");
var code = window.location.search.substr(1);

var svgBox = document.getElementById('map_canvas');
for (var x=0; x<25; x++) {
    for (var y=0; y<25; y++) {
        var element = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        element.setAttributeNS(null, 'width', 20);
        element.setAttributeNS(null, 'height', 20);
        element.setAttributeNS(null, 'x', x * 20);
        element.setAttributeNS(null, 'y', y * 20);
        element.setAttributeNS(null, 'id', 'pos_' + x + '_' + y);
        element.setAttributeNS(null, 'class', 'empty');


        var text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        text.setAttributeNS(null, 'x', x * 20+10);
        text.setAttributeNS(null, 'y', y * 20+10);
        text.setAttributeNS(null, 'id', 'text_' + x + '_' + y);
        text.setAttributeNS(null, 'class', 'empty');
        text.setAttributeNS(null, 'text-anchor', 'middle');
        text.setAttributeNS(null, 'alignment-baseline', 'middle');

        svgBox.appendChild(element);
        svgBox.appendChild(text);
    }
}

document.querySelectorAll("textarea").forEach(function (textarea) {
    CodeMirror.fromTextArea(textarea, { lineNumbers: true, readOnly: true, autoRefresh: true });
});

exampleSocket.onopen = function (event) {
    console.log('Logging in using code ' + code);
    exampleSocket.send(JSON.stringify({type: 'login', code: code}));
}

exampleSocket.onmessage = function (event) {
    var data = JSON.parse(event.data);
    if (data.type === 'map') {

        if (data.time) {
            var remaining = document.getElementById('time_remaining');
            var str = '';
            str += (''+Math.floor(data.time/60)).padStart(2,'0');
            str += ':';
            str += (''+(Math.floor(data.time)%60)).padStart(2,'0');

            remaining.textContent = str;
        }

        if (data.scores) {
            for (var i=0; i< data.scores.length; i++) {
                var score = document.getElementById('score_' + i);
                score.textContent = '' + data.scores[i];
            }
        }

        if (data.internal) {
            for (var i=0; i<data.internal.length; i++) {
                for (var st=0; st<10; st++) {
                    var color = null;
                    if (data.internal[i][0] == st) {
                        color = '#006400;'
                    }
                    var btn = document.getElementById('state_' + i + '_' + st);
                    if (btn) {
                        if (color) {
                            btn.style = 'background-color: ' + color;
                        } else {
                            btn.style = '';
                        }
                    }
                }
                var memory = document.getElementById('memory_' + i);
                if (memory) {
                    memory.textContent = JSON.stringify(data.internal[i][1]);
                }
            }
        }

        if (data.errors) {
            for (var i=0; i< data.errors.length; i++) {
                var error = document.getElementById('error_' + i);
                if (error) {
                    if (data.errors[i] && data.errors[i][1]) {
                        var errorMessage = 'Error: ' + data.errors[i][1] + '\n';
                        if (data.errors[i][2] && Array.isArray(data.errors[i][2])) {
                            data.errors[i][2].forEach(function(value) {
                                errorMessage += value + '\n';
                            });
                        }
                        error.textContent = errorMessage;
                        error.style = 'display: block;';
                    } else {
                        error.textContent = '';
                        error.style = 'display: none;';
                    }
                }
            }
        }

        for (x=0; x<25; x++) {
            for (y=0; y<25; y++) {
                var pos = data.data[x][y];
                var type = pos.t;
                var player = pos.team;
                var text = '';

                var klass = '';

                if (type === ' ') {
                    klass = 'empty';
                } else if (type === 'H') {
                    klass = 'hq team_' + player;
                } else if (type === 'R') {
                    klass = 'robot team_'+player;
                    text = pos.id;
                    if (pos.inv) {
                        text = text + '*';
                    }
                } else if (type === 'B') {
                    klass = 'gold';
                    text = pos.value;
                } else {
                    klass = 'wall';
                }

                var rect = document.getElementById('pos_'+x+'_'+y);
                rect.setAttributeNS(null, 'class', klass);

                var textBox = document.getElementById('text_' + x + '_' + y);
                textBox.setAttributeNS(null, 'class', klass);
                textBox.textContent = text;
            }
        }
    } else if (data.type == 'code') {
        var controls = document.getElementById("controls_div");

        for (var i = 0; i < data.data.length; i++) {
            var button = document.createElement('button');
            button.textContent = '' + i;
            button.id = 'robot_selector_' + i;
            button.setAttribute('class', 'robot_selector');
            if (i == 0) {
                button.style = 'background-color: darkgreen;';
            }

            button.onclick = (function(robot_id) {
                return function() {
                    for (var ii=0; ii < 20; ii++) {
                        var ctr = document.getElementById('controls_'+ii);
                        if (ctr) {
                            if (ii == robot_id) {
                                ctr.style = '';
                            } else {
                                ctr.style = 'display: none;';
                            }
                        }

                        var btn = document.getElementById('robot_selector_'+ii);
                        if (btn) {
                            if (ii == robot_id) {
                                btn.style = 'background-color: darkgreen;';
                            } else {
                                btn.style = '';
                            }
                        }
                    }
                }
            })(i);

            controls.appendChild(button);
            if ((i+1)%5==0) {
                controls.appendChild(document.createElement('br'));
            }
        }

        controls.appendChild(document.createElement('br'));

        for (var i = 0; i < data.data.length; i++) {
            var header = document.createElement('h2');
            var code_wrapper = document.createElement('div');
            var textarea = document.createElement('textarea');
            var button = document.createElement('button');
            var buttonJs = document.createElement('button');
            var memory = document.createElement('pre');
            var errors = document.createElement('pre');
            var state_buttons = document.createElement('div');

            code_wrapper.id = 'controls_' + i;
            if (i!=0) {
                code_wrapper.style = 'display: none;';
            }

            header.textContent = 'Robot #' + i;
            memory.id = 'memory_' + i;
            memory.setAttribute('class','memory');
            textarea.value = data.data[i];
            button.textContent = 'Install Ruby code for Robot #' + i;
            button.style = 'width:100%;';
            buttonJs.textContent = 'Install JavaScript code for Robot #' + i;
            buttonJs.style = 'width:100%;';
            errors.id = 'error_' + i;
            errors.setAttribute('class','error');

            var state_header = document.createElement('h3');
            state_header.textContent = 'Robot #'+i+'\'s state';

            state_buttons.appendChild(state_header);

            for (var st = 0; st < 10; st++) {
                btn = document.createElement('button');
                btn.id = 'state_' + i + '_' + st;
                btn.textContent = '' + st;
                btn.onclick = (function(robot_id, state) {
                    return function() {
                        exampleSocket.send(JSON.stringify({type: 'state', code: code, robot_id: robot_id, new_state: state}));
                    }
                })(i, st);
                state_buttons.appendChild(btn);
            }

            code_wrapper.appendChild(header);
            code_wrapper.appendChild(textarea);
            code_wrapper.appendChild(button);
            code_wrapper.appendChild(buttonJs);
            code_wrapper.appendChild(document.createElement('br'));
            code_wrapper.appendChild(document.createElement('br'));
            code_wrapper.appendChild(state_buttons);

            code_wrapper.appendChild(document.createElement('br'));
            var memory_header = document.createElement('h3');
            memory_header.textContent = 'Robot #'+i+'\'s memory';

            code_wrapper.appendChild(memory_header);
            code_wrapper.appendChild(memory);

            code_wrapper.appendChild(errors);

            controls.appendChild(code_wrapper);

            var cm = CodeMirror.fromTextArea(textarea, { lineNumbers: true, autoRefresh: true });

            button.onclick = (function(robot_id, text, codemirror) {
                return function() {
                    codemirror.save();
                    codemirror.setOption("mode", 'ruby');
                    exampleSocket.send(JSON.stringify({type: 'code', code: code, robot_id: robot_id, new_code: text.value, language: 'ruby'}));
                }
            })(i, textarea, cm);

            buttonJs.onclick = (function(robot_id, text, codemirror) {
                return function() {
                    codemirror.save();
                    codemirror.setOption("mode", 'javascript');
                    exampleSocket.send(JSON.stringify({type: 'code', code: code, robot_id: robot_id, new_code: text.value, language: 'js'}));
                }
            })(i, textarea, cm);
        }
    }
}
