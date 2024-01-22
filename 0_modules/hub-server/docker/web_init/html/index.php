<!DOCTYPE html>
<html lang="es">
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" >
    <title>Cloud worshop – Fortinet </title>
    <!-- Add custom CSS styles -->
    <style>
        body {
            font-family: 'Arial', sans-serif;
            text-align: start;
            margin: 50px;
        }
        h1 {
            color: #333;
        }
        form {
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        label {
            margin-bottom: 10px;
        }
        input {
            padding: 5px;
            margin-bottom: 15px;
            width: 200px;
            box-sizing: border-box;
        }
        button {
            background-color: #4CAF50;
            color: white;
            padding: 5px 15px;
            font-size: 10px;
            cursor: pointer;
            border-radius: 2px;
            border: none;
        }
        button:hover {
            background-color: #45a049;
        }
        p {
            color: #333;
            text-align: start; 
            margin: 10px;
        }
    </style>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>
    <script>
        function hide_studentdata(){
                $("#js_result_studentdata").text("");
        };
	function get_studentdata(){
                url = "functions/get_studentdata.php";
                data = { email : $("#txt_email").val()}
                $.post( url, data, function(data) {
                        document.getElementById('js_result_studentdata').innerHTML = data;
                });
        };
	function get_leaderboard(){
                url = "functions/get_leaderboard.php";
                $("#table").text("")
                $.get( url, function(data, status){
                        document.getElementById('js_result_leaderboard').innerHTML = data;
                });
        };
	$(document).ready(function() {
	   setInterval(get_leaderboard, 10000);
	});
  </script>
  </head>
  <body>
    <h1><span style="color:Red">Fortinet</span> - AWS SDWAN Hands-on-Lab</h1>
    <h2>Cloud workshop</h2>
    <h3>Guía y repositorio del laboratorio: <a href="https://github.com/jmvigueras/sdwan-aws-hands-on-lab">AWS SDWAN Lab GitRepo</a></h3>
    <hr/>
    <h3>Student data: </h3>
        <label for="email">Enter your email:</label>
        <input type="email" id="txt_email" name="email"> 
        <button id="btn1" type="button" onclick="get_studentdata()">Show</button>
        <button id="btn2" type="button" onclick="hide_studentdata()">Hide</button>
        <pre>
        <code id="js_result_studentdata"></code>
        </pre>
    <hr/>
    <h2>Leader board</h2>
        <p id="js_result_leaderboard"></p>
    <hr/>
  </body>
</html>

