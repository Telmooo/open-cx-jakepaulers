import 'dart:async';

import 'package:askkit/Model/Answer.dart';
import 'package:askkit/Model/Question.dart';
import 'package:askkit/Model/User.dart';
import 'package:askkit/View/Controllers/DatabaseController.dart';
import 'package:askkit/View/Controllers/ModelListener.dart';
import 'package:askkit/View/Pages/ManageCommentPage.dart';
import 'package:askkit/View/Widgets/AnswerCard.dart';
import 'package:askkit/View/Widgets/Borders.dart';
import 'package:askkit/View/Widgets/CardTemplate.dart';
import 'package:askkit/View/Widgets/CenterText.dart';
import 'package:askkit/View/Widgets/DynamicFAB.dart';
import 'package:askkit/View/Widgets/QuestionCard.dart';
import 'package:flutter/material.dart';

class AnswersPage extends StatefulWidget {
  Question _question;
  ModelListener _listener;
  final DatabaseController _dbcontroller;

  AnswersPage(this._question, this._listener, this._dbcontroller);

  @override
  State<StatefulWidget> createState() {
    return AnswersPageState();
  }

}

class AnswersPageState extends State<AnswersPage> implements ModelListener {
  List<Answer> answers = new List();

  bool loading = false;
  Timer minuteTimer;
  ScrollController scrollController;

  @override void initState() {
    scrollController = ScrollController();
    minuteTimer = Timer.periodic(Duration(minutes: 1), (t) { setState(() { }); });
    this.refreshModel();
  }

  @override void dispose() {
    minuteTimer.cancel();
    super.dispose();
  }

  void refreshModel() {
    this.fetchQuestion();
    this.fetchAnswers();

    if (scrollController.hasClients)
      scrollController.animateTo(0, duration: Duration(seconds: 1), curve: Curves.ease);
  }

  void fetchQuestion() async {
    try {
      Question question = await widget._dbcontroller.refreshQuestion(widget._question);
      setState(() { widget._question = question; });
    } on Error {
      Navigator.pop(context);
      widget._listener.refreshModel();
    }
  }

  void fetchAnswers() async {
    Stopwatch sw = Stopwatch()..start();
    setState(() { loading = true; });
    answers = await widget._dbcontroller.getAnswers(widget._question);
    if (this.mounted)
      setState(() { loading = false; });
    print("Answer fetch time: " + sw.elapsed.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text("Answers"),
            backgroundColor: Theme.of(context).primaryColor,
            actions: <Widget>[
              IconButton(icon: Icon(Icons.refresh), onPressed: refreshModel),
            ],
        ),
        backgroundColor: Theme.of(context).backgroundColor,
        body: getBody(),
        floatingActionButton: DynamicFAB(scrollController, () => addAnswerForm(context)),
    );
  }

  Widget getBody() {
    return Column(
        children: <Widget>[
          QuestionCard(this, widget._question, false, widget._dbcontroller),
          Divider(color: CardTemplate.cardShadowColor, thickness: 1.0, height: 1.0),
          Visibility(visible: this.loading, child: LinearProgressIndicator()),
          Expanded(child: answerList(widget._question))
        ]
    );
  }

  Widget answerList(Question question) {
    if (answers.length == 0 && !this.loading)
      return CenterText("This human needs assistance!\nLet's help him! 😃", textScale: 1.25);
    return ListView.builder(
        controller: scrollController,
        itemCount: answers.length,
        itemBuilder: (BuildContext context, int i) {
          return Container(
              decoration: BoxDecoration(border: BorderLeft(Theme.of(context).primaryColor, 4.0)),
              child: Column(
                children: <Widget>[
                  AnswerCard(this, answers[i], widget._dbcontroller),
                  Divider(color: CardTemplate.cardShadowColor, thickness: 1.0, height: 1.0),
                ],
              )
          );
        }
    );
  }

  void addAnswerForm(BuildContext context) async {
    Widget answerPage = NewAnswerPage(widget._question);
    String comment = await Navigator.push(context, MaterialPageRoute(builder: (context) => answerPage));
    if (comment == null)
      return;
    User user = await widget._dbcontroller.getCurrentUser();
    await widget._dbcontroller.addAnswer(Answer(user, comment, DateTime.now(), widget._question.reference, null));
    refreshModel();
  }
}
